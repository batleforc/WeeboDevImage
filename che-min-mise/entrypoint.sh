#!/bin/bash

# Replace /home/tooling/* path to /home/user/* path
replace_user_home() {
  echo "$1" | sed "s|^/home/tooling|$HOME|"
}

# Ensure $HOME exists when starting
if [ ! -d "${HOME}" ]; then
  mkdir -p "${HOME}"
fi

# Configure container builds to use vfs or fuse-overlayfs
if [ ! -d "${HOME}/.config/containers" ]; then
  mkdir -p ${HOME}/.config/containers
  if [ -c "/dev/fuse" ] && [ -f "/usr/bin/fuse-overlayfs" ]; then
    (echo '[storage]';echo 'driver = "overlay"';echo '[storage.options.overlay]';echo 'mount_program = "/usr/bin/fuse-overlayfs"') > ${HOME}/.config/containers/storage.conf
  else
    (echo '[storage]';echo 'driver = "vfs"') > "${HOME}"/.config/containers/storage.conf
  fi
fi

# The image bakes uid 1234 (the uid weebo-si forces), so whoami resolves and
# nothing below runs. For any other uid (OpenShift arbitrary UID), register it
# so tools that resolve UID -> name work, without touching /etc/passwd: it is
# root:root 0644 and the user cannot write it.
#
# nss_wrapper. We synthesize the passwd/group entry in a per-user
# file and load it via LD_PRELOAD, which lets /etc/passwd stay root:root 0644 —
# so it can NOT be edited to inject a fake uid-0 user. Images opt in simply by
# installing libnss-wrapper (see che-mise-nss); nothing else changes here.

# Login shell for the entry written below: USER_SHELL=zsh opts into zsh (+ oh-my-zsh), bash otherwise
USER_SHELL_PATH=/bin/bash
if [ "${USER_SHELL:-bash}" = "zsh" ] && command -v zsh &> /dev/null; then
  USER_SHELL_PATH="$(command -v zsh)"
fi

if ! whoami &> /dev/null; then
  nss_lib=$(find /usr/lib64 /usr/lib /lib64 /lib -name 'libnss_wrapper.so*' 2>/dev/null | head -n1)
  if [ -n "${nss_lib}" ]; then
    : "${HOME:=/home/user}"
    NSS_WRAPPER_PASSWD="${HOME}/.nss_passwd"
    NSS_WRAPPER_GROUP="${HOME}/.nss_group"
    cp /etc/passwd "${NSS_WRAPPER_PASSWD}" 2>/dev/null || : > "${NSS_WRAPPER_PASSWD}"
    cp /etc/group  "${NSS_WRAPPER_GROUP}"  2>/dev/null || : > "${NSS_WRAPPER_GROUP}"
    echo "${USER_NAME:-user}:x:$(id -u):0:${USER_NAME:-user} user:${HOME}:${USER_SHELL_PATH}" >> "${NSS_WRAPPER_PASSWD}"
    echo "${USER_NAME:-user}:x:$(id -u):" >> "${NSS_WRAPPER_GROUP}"
    export NSS_WRAPPER_PASSWD NSS_WRAPPER_GROUP
    export LD_PRELOAD="${nss_lib}${LD_PRELOAD:+:${LD_PRELOAD}}"
    echo "Registered ${USER_NAME:-user} ($(id -u)) via nss_wrapper; /etc/passwd left read-only"
  fi
fi

# /etc/subuid and /etc/subgid are no longer rewritten for user namespaces:
# they are read-only, and rootless podman cannot run in a weebo-si workspace
# anyway (newuidmap is setuid, no_new_privs ignores it).

# Stow
## Required for https://github.com/eclipse/che/issues/22412

# /home/user/ will be mounted to by a PVC if persistUserHome is enabled
mountpoint -q /home/user/; HOME_USER_MOUNTED=$?

# This file will be created after stowing, to guard from executing stow everytime the container is started
STOW_COMPLETE=/home/user/.stow_completed

if [ $HOME_USER_MOUNTED -eq 0 ] && [ ! -f $STOW_COMPLETE ]; then
    # There may be regular, non-symlink files in /home/user that match the
    # pathing of files in /home/tooling. Stow will error out when it tries to
    # stow on top of that. Instead, we can append to the current
    # /home/tooling/.stow-local-ignore file to ignore pre-existing,
    # non-symlinked files in /home/user that match those in /home/tooling before
    # we run stow.
    #
    # Create two text files containing a sorted path-based list of files in
    # /home/tooling and /home/user. Cut off "/home/user" and "/home/tooling" and
    # only get the sub-paths so we can do a proper comparison
    #
    # In the case of /home/user, we want regular file types and not symbolic
    # links.
    find /home/user -type f -xtype f -print  | sort | sed 's|/home/user||g' > /tmp/user.txt
    find /home/tooling -print | sort | sed 's|/home/tooling||g' > /tmp/tooling.txt
    # We compare the two files, trying to find files that exist in /home/user
    # and /home/tooling. Being that the files that get flagged here are not
    # already synlinks, we will want to ignore them.
    IGNORE_FILES="$(comm -12 /tmp/user.txt /tmp/tooling.txt)"
    # We no longer require the file lists, so remove them
    rm /tmp/user.txt /tmp/tooling.txt
    # Each file to ignore is passed as an --ignore regex instead of being
    # appended to /home/tooling/.stow-local-ignore: that file lives on the
    # rootfs, which is read-only in che-mise-nss. --ignore is additive to the
    # local ignore file. Stow matches the regex against the package-relative
    # path without a leading slash, anchored only at the end — so strip the
    # slash, escape regex metacharacters, and anchor the start ourselves.
    STOW_IGNORE_FLAGS=()
    for f in $IGNORE_FILES; do
        escaped=$(printf '%s' "${f#/}" | sed 's/[][\.*^$(){}?+|]/\\&/g')
        STOW_IGNORE_FLAGS+=("--ignore=^${escaped}")
    done
    # We are now ready to run stow
    #
    # Create symbolic links from /home/tooling/ -> /home/user/
    stow . -t /home/user/ -d /home/tooling/ --no-folding -v 2 "${STOW_IGNORE_FLAGS[@]}" > /tmp/stow.log 2>&1
    touch $STOW_COMPLETE
fi

# Read .copy-files and copy files from /home/tooling to /home/user
if [ -f "/home/tooling/.copy-files" ]; then
    echo "Processing .copy-files..."
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip empty and commented lines
        [[ -z "$line" || "$line" == \#* ]] && continue

        if [ -e "/home/tooling/$line" ]; then
            tooling_path=$(realpath "/home/tooling/$line")

            # Determine target path based on whether source is a directory
            if [ -d "$tooling_path" ]; then
                # For directories: copy to parent directory (e.g., dir1/dir2 -> /home/user/dir1/)
                target_parent=$(dirname "${HOME}/${line}")
                target_full="$target_parent/$(basename "$tooling_path")"

                # Skip if target directory already exists
                if [ -d "$target_full" ]; then
                    echo "Directory $target_full already exists, skipping..."
                    continue
                fi

                echo "Copying directory $tooling_path to $target_parent/"
                mkdir -p "$target_parent"
                cp --no-clobber -r "$tooling_path" "$target_parent/"
            else
                # For files: copy to exact target path
                target_full="${HOME}/${line}"
                target_parent=$(dirname "$target_full")

                # A link left into /home/tooling by an older image is replaced by the copy
                if [ -L "$target_full" ] && [ "$(realpath "$target_full" 2>/dev/null)" = "$tooling_path" ]; then
                    rm -f "$target_full"
                fi

                # Skip if target file already exists
                if [ -e "$target_full" ]; then
                    echo "File $target_full already exists, skipping..."
                    continue
                fi

                echo "Copying file $tooling_path to $target_full"
                mkdir -p "$target_parent"
                cp --no-clobber -r "$tooling_path" "$target_full"
            fi
        else
            echo "Warning: /home/tooling/$line does not exist, skipping..."
        fi
    done < /home/tooling/.copy-files
    echo "Finished processing .copy-files."
else
    echo "No .copy-files found, skipping copy operation."
fi

# Create symlinks from /home/tooling/.config to /home/user/.config
# Only create symlinks for files that don't already exist in destination.
# This is done because stow ignores the .config directory.
if [ -d /home/tooling/.config ]; then
    echo "Creating .config symlinks for files that don't already exist..."

    # Find all files recursively in /home/tooling/.config
    find /home/tooling/.config -type f | while read -r file; do
        # Get the relative path from /home/tooling/.config
        relative_path="${file#/home/tooling/.config/}"

        # Determine target path in /home/user/.config
        target_file="${HOME}/.config/${relative_path}"
        target_dir=$(dirname "$target_file")

        # Only create symlink if target file doesn't exist
        if [ ! -e "$target_file" ]; then
            # Create target directory if it doesn't exist
            mkdir -p "$target_dir"
            # Create symbolic link
            ln -s "$file" "$target_file"
            echo "Created symlink: $target_file -> $file"
        else
            echo "File $target_file already exists, skipping..."
        fi
    done

    echo "Finished creating .config symlinks."
fi

# Setup CHEZMOI has a dotfile handler
# Bounded by a timeout: an unreachable dotfiles repo must not keep the workspace from starting
CHEZMOI_BASEPATH="/home/user/.local/share/chezmoi"
CHEZMOI_TIMEOUT="${CHEZMOI_TIMEOUT:-120}"
if [ -n "${CHEZMOI_URL}" ]; then
    echo "Chezmoi Exist"
    if [ ! -d "${CHEZMOI_BASEPATH}" ]; then
        echo "Init Chezmoi"
        timeout "${CHEZMOI_TIMEOUT}" chezmoi init --apply --no-tty "${CHEZMOI_URL}" \
            || echo "Warning: chezmoi init failed or timed out after ${CHEZMOI_TIMEOUT}s, skipping..."
    else
        echo "Update Chezmoi"
        timeout "${CHEZMOI_TIMEOUT}" chezmoi update --no-tty --keep-going \
            || echo "Warning: chezmoi update failed or timed out after ${CHEZMOI_TIMEOUT}s, skipping..."
    fi
else
    echo "Chezmoi url does not exist skip..."
fi


exec "$@"
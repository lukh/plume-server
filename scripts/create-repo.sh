#!/bin/bash

# RUN THIS SCRIPT DIRECTLY FROM THE HOST MACHINE, NOT FROM WITHIN THE DOCKER CONTAINER!

while true; do
    echo
    read -p "Enter the desired repository name to create:  "  REPO_NAME
    read -p "Confirm creation by re-entering the desired repository name again:  "  REPO_NAME_CONFIRMATION
    echo
    [ "$REPO_NAME" = "$REPO_NAME_CONFIRMATION" ] && break || echo "   ----- The two entered repo names don't match; please try again! -----"
done

if [ -z "$REPO_NAME" ]; then
    echo
    echo "ERROR: Repository name can't (and shouldn't...) be empty! Please provide a valid value!"
    exit 1
fi

if docker exec svn-server test -d "/home/svn/$REPO_NAME"; then
    echo "Repository already exists !"
    exit 1
fi

echo

read -p "Enter the repository title:  "  REPO_TITLE
read -p "Enter the repository description:  "  REPO_DESC

echo

read -p "Enter the Inventree URL:  "  INVENTREE_URL

echo

read -p "publish exports to Inventree [true|false] [true]:  "  EXPORT_INVENTREE
EXPORT_INVENTREE="${EXPORT_INVENTREE:-true}"
[ "$EXPORT_INVENTREE" = "true" ] || [ "$EXPORT_INVENTREE" = "false" ] || {
    echo "Error: must be true|false"
    exit 1
}


read -p "Publish exports to Subversion [true|false] [true]: " EXPORT_SVN
EXPORT_SVN="${EXPORT_SVN:-true}"
[ "$EXPORT_SVN" = "true" ] || [ "$EXPORT_SVN" = "false" ] || {
    echo "Error: must be true|false"
    exit 1
}

read -p "Subversion export mode [subfolder|rootfolder] [subfolder] ?:  "  SVN_EXPORT_MODE
SVN_EXPORT_MODE="${SVN_EXPORT_MODE:-subfolder}"
[ "$SVN_EXPORT_MODE" = "subfolder" ] || [ "$SVN_EXPORT_MODE" = "rootfolder" ] || {
    echo "Error: must be subfolder|rootfolder"
    exit 1
}


read -p "Subversion export rootfolder (relative to repo) [exports] ?:  "  SVN_EXPORT_ROOTFOLDER
SVN_EXPORT_ROOTFOLDER="${SVN_EXPORT_ROOTFOLDER:-exports}"

read -p "Subversion export subfolder (relative to project) ?:  "  SVN_EXPORT_SUBFOLDER
SVN_EXPORT_SUBFOLDER="${SVN_EXPORT_SUBFOLDER:-exports}"



##########################################################
# Initiate repo creation
##########################################################

docker exec -it svn-server svnadmin create /home/svn/$REPO_NAME
docker exec -it svn-server chown -R www-data:subversion /home/svn/$REPO_NAME
docker exec -it svn-server chmod -R g+rws /home/svn/$REPO_NAME

##########################################################
# Adding hooks
##########################################################


echo
echo "Installing hooks..."

#
# PRE-COMMIT
#
docker exec -i svn-server bash <<EOF
cat > /home/svn/$REPO_NAME/hooks/pre-commit <<'HOOK'
#!/bin/sh

REPOS="\$1"
TXN="\$2"

SVNLOOK=/usr/bin/svnlook

AUTHOR=\$(\$SVNLOOK author -t "\$TXN" "\$REPOS")


#======================================
# Protect releases|exports|tags folders
#======================================
# .From https://www.ryanschulze.net/archives/1563

# Note : Tagging, released are done
#   - with a folder svn copy (for tagging)
#   - with copying files (svn local copy) and commiting the full folder
# So locking file ADD on this folder will work

# for changes in  releases|$SVN_EXPORT_SUBFOLDER|tags :
#   if it is a file :
#       ADD, UPDATE, DELETE, PROPS are forbidden
#   if folder :
#       DELETE, UPDATE are forbidden

ALLOWED_PATTERN=".*/MANIFEST\.md\$"

UPDATE=block
DELETE=block
# not implemented ADD=block
# not implemented COPY=allow
PROPERTIES=block


TMPFILE=\$(mktemp) || exit 1
trap 'rm -f "$TMPFILE"' EXIT

# "\$SVNLOOK" changed --copy-info -t "\$TXN" "\$REPOS" > "\$TMPFILE" || exit 1
"\$SVNLOOK" changed -t "\$TXN" "\$REPOS" > "\$TMPFILE" || exit 1

while read -r line
do
    ACTION="\${line%% *}"
    FILE_PATH="\$(printf '%s\n' "\${line#* }" | sed 's/^ *//')"

    if printf '%s\n' "\$FILE_PATH" | grep -Eq '.*(releases|$SVN_EXPORT_SUBFOLDER|tags)\/.*\$'; then
        case "\$ACTION" in
            U|UU)
                [ "\$UPDATE" = "block" ] && {
                    echo "Cannot UPDATE on protected releases|$SVN_EXPORT_SUBFOLDER|tags! (\${FILE_PATH})" >&2
                    exit 1
                }
                ;;
            D)
                [ "\$DELETE" = "block" ] && {
                    echo "Cannot DELETE on protected releases|$SVN_EXPORT_SUBFOLDER|tags! (\${FILE_PATH})" >&2
                    exit 1
                }
                ;;
            
            _U)
                [ "\$PROPERTIES" = "block" ] && {
                    echo "Cannot PROPERTIES on protected releases|$SVN_EXPORT_SUBFOLDER|tags! (\${FILE_PATH})" >&2
                    exit 1
                }
                ;;

            # "A +*")
            #     [ "\$COPY" = "block" ] && {
            #         echo "Cannot COPY on protected releases|$SVN_EXPORT_SUBFOLDER|tags! (\${FILE_PATH})" >&2
            #         exit 1
            #     }
            #     ;;
            # A)
            # "A *")
            #     if [ "\$ADD" = "block" ]
            #         # &&
            #         # [ "\${FILE_PATH%/}" = "\$FILE_PATH" ] ;
            #         # &&
            #         # ! printf '%s\n' "\$FILE_PATH" | grep -Eq "\$ALLOWED_PATTERN";
            #     then
            #         echo "Cannot ADD on protected releases|$SVN_EXPORT_SUBFOLDER|tags! (\${FILE_PATH})" >&2
            #         exit 1
            #     fi
            #     ;;
        esac
    fi
done < "\$TMPFILE"





#=============================================
# Lock : needs-lock, lock owner and not locked
#=============================================



LOCKED_EXTENSIONS="FCStd step stp iges igs slvs"

is_locked_extension() {
    FILE="\$1"
    EXT="\${FILE##*.}"

    for E in \$LOCKED_EXTENSIONS
    do
        [ "\$EXT" = "\$E" ] && return 0
    done

    return 1
}

\$SVNLOOK changed -t "\$TXN" "\$REPOS" | while read CHANGE FILE
do

    case "\$CHANGE" in
        D)
            continue
            ;;
    esac

    is_locked_extension "\$FILE" || continue

    PROP=\$(\$SVNLOOK propget \
        -t "\$TXN" \
        "\$REPOS" \
        svn:needs-lock \
        "\$FILE")

    if [ -z "\$PROP" ]; then
        echo ""
        echo "ERROR: missing svn:needs-lock"
        echo "  \$FILE"
        exit 1
    fi

    LOCK_OWNER=\$(\$SVNLOOK lock "\$REPOS" "\$FILE" 2>/dev/null | \
        grep "^Owner:" | awk '{print \$2}')

    if [ -z "\$LOCK_OWNER" ]; then
        echo ""
        echo "ERROR: file must be locked"
        echo "  \$FILE"
        exit 1
    fi

    if [ "\$LOCK_OWNER" != "\$AUTHOR" ]; then
        echo ""
        echo "ERROR: lock owned by another user"
        echo "  File : \$FILE"
        echo "  Owner: \$LOCK_OWNER"
        echo "  User : \$AUTHOR"
        exit 1
    fi

done

exit 0
HOOK
EOF

#
# PRE-LOCK
#
docker exec -i svn-server bash <<EOF
cat > /home/svn/$REPO_NAME/hooks/pre-lock <<'HOOK'
#!/bin/sh

REPOS="\$1"
PATH="\$2"
USER="\$3"
COMMENT="\$4"
STEAL="\$5"

LOCKED_EXTENSIONS="FCStd step stp iges igs slvs"

EXT="\${PATH##*.}"

NEED_LOCK=0

for E in \$LOCKED_EXTENSIONS
do
    [ "\$EXT" = "\$E" ] && NEED_LOCK=1
done

[ "\$NEED_LOCK" -eq 0 ] && exit 0

if [ "\$STEAL" = "1" ]; then
    echo ""
    echo "ERROR: Stealing locks forbidden."
    echo ""
    exit 1
fi

# if [ -z "\$COMMENT" ]; then
#     echo ""
#     echo "ERROR: Lock comment required."
#     echo ""
#     exit 1
# fi

# LEN=\$(echo "\$COMMENT" | wc -c)

# if [ "\$LEN" -lt 10 ]; then
#     echo ""
#     echo "ERROR: Lock comment too short."
#     echo ""
#     exit 1
# fi

exit 0
HOOK
EOF

#
# PRE-UNLOCK
#
docker exec -i svn-server bash <<EOF
cat > /home/svn/$REPO_NAME/hooks/pre-unlock <<'HOOK'
#!/bin/sh

REPOS="\$1"
PATH="\$2"
USER="\$3"
TOKEN="\$4"
BREAK="\$5"

SVNLOOK=/usr/bin/svnlook

if [ "\$BREAK" = "1" ]; then
    echo ""
    echo "ERROR: Forced unlock forbidden."
    echo ""
    exit 1
fi

LOCK_OWNER=\$(\$SVNLOOK lock "\$REPOS" "\$PATH" 2>/dev/null | \
    grep "^Owner:" | awk '{print \$2}')

if [ "\$LOCK_OWNER" != "\$USER" ]; then
    echo ""
    echo "ERROR: You do not own this lock."
    echo ""
    exit 1
fi

exit 0
HOOK
EOF

echo
echo "Applying permissions..."

docker exec svn-server chmod +x /home/svn/$REPO_NAME/hooks/pre-commit
docker exec svn-server chmod +x /home/svn/$REPO_NAME/hooks/pre-lock
docker exec svn-server chmod +x /home/svn/$REPO_NAME/hooks/pre-unlock


##########################################################
# Populate the repo
##########################################################
TMPDIR=$(
    docker exec -i svn-server bash <<'EOF'
        mktemp -d
EOF
)
echo "TMPDIR=$TMPDIR"


echo "Adding initial directory tree"
while true; do
    read -p "Enter path to add to repository, then press Enter, or Enter to pass: " NEW_REPO_SUBDIR
    [[ -z $NEW_REPO_SUBDIR ]] && break

    echo $NEW_REPO_SUBDIR
    
    docker exec -i svn-server mkdir -p $TMPDIR/$NEW_REPO_SUBDIR
done


echo
echo "Adding .plume.json"
docker exec -i svn-server bash <<EOF
cat > $TMPDIR/.plume.json <<'PLUMECONF'
{
    "inventree_url": "$INVENTREE_URL",
    "plume_ipn_autogenerated": false,
    "export_in_inventree": $EXPORT_INVENTREE,
    "export_in_svn": $EXPORT_SVN,
    "svn_export_mode": "$SVN_EXPORT_MODE",
    "svn_export_rootfolder": "$SVN_EXPORT_ROOTFOLDER",
    "svn_export_subfolder": "$SVN_EXPORT_SUBFOLDER"
}
PLUMECONF
EOF

echo "Adding README.md"
docker exec -i svn-server bash <<EOF
cat > $TMPDIR/README.md <<'README'
$REPO_TITLE
================

$REPO_DESC

Tree
----

README
EOF

docker exec -i svn-server bash <<EOF
echo '\`\`\`text' | tee -a "$TMPDIR/README.md"
tree "$TMPDIR" -d --noreport | sed '1d' | tee -a "$TMPDIR/README.md"
echo '\`\`\`' | tee -a "$TMPDIR/README.md"
EOF


docker exec -i svn-server bash <<EOF
svn import "$TMPDIR" "file:///home/svn/$REPO_NAME" \
    -m "Initial repository structure"

rm -rf "$TMPDIR"
EOF


##########################################################
# Set default authorisations for the new repo
##########################################################

docker exec -i svn-server bash <<EOF
cat >> /home/svn/authz <<'AUTHZ'
[$REPO_NAME:/]
\$anonymous = 
\$authenticated = rw

AUTHZ
EOF


##########################################################
# Summary
##########################################################


echo
echo "Repository created successfully:"
echo "  $REPO_NAME"
echo
echo "Hooks installed:"
echo "  - pre-commit"
echo "  - pre-lock"
echo "  - pre-unlock"
echo
echo "Added files:"
echo "  - .plume.json"
echo "  - README.md"
echo
echo "Added initial tree..."
echo
echo "ATTENTION: Remember to add svn:needs-lock properties in your working copy."
echo "ATTENTION: default authorisations have been given : rw for all authorized users, no access for anonymous. fine tune if needed."
echo "Good luck !"

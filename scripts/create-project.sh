read -p "Enter the desired repository name to create project in:  "  REPO_NAME


if ! docker exec -i svn-server test -e "/home/svn/$REPO_NAME"; then
    echo "Repo doesn't exists"
    exit 1
fi


while true; do

read -p "Enter the desired project path, will be created if doesn't exist:  "  PROJECT_PATH

[[ -z $PROJECT_PATH ]] && break


# not working, use svn cmd...
if docker exec -i svn-server test -e "/home/svn/$REPO_NAME/$PROJECT_PATH"; then
    echo "Project exists"
    exit 1
fi


read -p "About to create $PROJECT_PATH under $REPO_NAME. Continue? [yes/no]: " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Project creation cancelled."
    exit 0
fi

TMPDIR=$(
    docker exec -i svn-server bash <<'EOF'
        mktemp -d
EOF
)

docker exec -i svn-server mkdir -p "$TMPDIR/trunk"
docker exec -i svn-server mkdir -p "$TMPDIR/tags"
docker exec -i svn-server mkdir -p "$TMPDIR/branches"
docker exec -i svn-server mkdir -p "$TMPDIR/releases"
docker exec -i svn-server mkdir -p "$TMPDIR/exports" # TODO : catch the svn_export_subfolder key in .plume.json 


docker exec -i svn-server bash <<EOF
svn import "$TMPDIR" "file:///home/svn/$REPO_NAME/$PROJECT_PATH" \
    -m "Initial repository structure"

rm -rf "$TMPDIR"
EOF

done
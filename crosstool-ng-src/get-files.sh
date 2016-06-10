# shell script to add additional files

#FILES_URL="http://files.astlinux.org"
FILES_URL="http://d18y2f4fr43xzs.cloudfront.net"

TARBALLS=".build/tarballs"

LINUX_KERNEL="linux-3.2.80.tar.gz"

EGLIBC="eglibc-2_18.tar.bz2"

if [ ! -f "$LINUX_KERNEL" ]; then
  echo "Downloading $FILES_URL/$LINUX_KERNEL ..."
  wget "$FILES_URL/$LINUX_KERNEL"
fi

if [ ! -f "$TARBALLS/$EGLIBC" ]; then
  echo "Downloading $FILES_URL/$EGLIBC ..."
  wget "$FILES_URL/$EGLIBC"

  mkdir -p "$TARBALLS"
  mv "$EGLIBC" "$TARBALLS/$EGLIBC"
fi

exit 0

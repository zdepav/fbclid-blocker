#! /bin/sh

# parse arguments
debug=""
autofix_npm=""
for arg in "$@"
do
  case "$arg" in
    --debug)
      debug=true
      ;;
    --autofix-npm)
      autofix_npm=true
      ;;
    clean)
      rm -rf build/
      exit 0
      ;;
    *)
      echo "invalid argument \"$arg\"" >&2
      exit 1
      ;;
  esac
done

check_commands_available() {
  all_ok=true
  for cmd in "$@"
  do
    if ! command -v "$cmd" > /dev/null 2>&1
    then
      echo "program \"$cmd\" is missing" >&2
      all_ok=false
    fi
  done
  if [ $all_ok = true ]
  then return 0
  else return 1
  fi
}

ensure_npm_packages_available() {
  for package in "$@"
  do
    if ! npm list -g "$package" > /dev/null 2>&1
    then
      npm install -g "$package"
    fi
  done
}

check_npm_packages_available() {
  all_ok=true
  for package in "$@"
  do
    if ! npm list -g "$package" > /dev/null 2>&1
    then
      echo "npm package \"$package\" is missing" >&2
      all_ok=false
    fi
  done
  if [ $all_ok = true ]
  then
    return 0
  else
    echo "run with --autofix-npm to automatically install missing packages"
    return 1
  fi
}

compile_ts() {
  if tsc --removeComments --outFile "build/$1.js" "$1.ts"
  then return 0
  else return 1
  fi
}

compile_minify_ts() {
  if tsc --removeComments --outFile "build/$1.tmp.js" "$1.ts" \
  && minify "build/$1.tmp.js" > "build/$1.js" \
  && rm -f "build/$1.tmp.js"
  then return 0
  else return 1
  fi
}

check_commands_available npm 7z || exit 1
if [ $autofix_npm ]
then ensure_npm_packages_available typescript minify
else check_npm_packages_available typescript minify || exit 1
fi

if [ -d build ]
then rm -rf build/*
fi
mkdir -p build/src/ || exit 1

version=$(grep -F '"version": "' manifest.json | grep -oE '[0-9]+(\.[0-9]+)+')
archive_base_name="fbclid-blocker-$(echo "$version" | sed -E 's/\./-/g')"
echo "building version $version:"

echo "copying source files"
cp *.ts store/firefox/README build/src/ || exit 1

echo "packing source zip archive"
cd build/src/
7z a "$archive_base_name-source.zip" -- *.ts README > /dev/null 2>&1 || exit 1
cd ../../
mv "build/src/$archive_base_name-source.zip" dist/ || exit 1

rm -rf build/*

echo "compiling typecript"
if [ $debug ]
then
  compile_ts fbclid-blocker-fb || exit 1
  compile_ts fbclid-blocker-nonfb || exit 1
else
  compile_minify_ts fbclid-blocker-fb || exit 1
  compile_minify_ts fbclid-blocker-nonfb || exit 1
fi

echo "copying add-on files"
minify fbclid-blocker.html > build/fbclid-blocker.html || exit 1
cp icon/*.png manifest.json build/ || exit 1

echo "packing zip archive"
cd build/
7z a "$archive_base_name.zip" -- *.png *.js *.html *.json > /dev/null 2>&1 || exit 1
cd ../
mv "build/$archive_base_name.zip" dist/ || exit 1

echo "done"

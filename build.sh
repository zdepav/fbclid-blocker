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

debug_compile_ts() {
  if sed -E 's@/\*\s*debug\s+begin\s*\*/@@gi;s@/\*\s*debug\s+end\s*\*/@@gi;s@/\*\s*release\s+begin\s*\*/@/*@gi;s@/\*\s*release\s+end\s*\*/@*/@gi' < "$1.ts" > "build/$1.ts" \
  && tsc --removeComments --outFile "build/$1.js" "$1.ts" \
  && rm -f "build/$1.ts"
  then return 0
  else return 1
  fi
}

compile_minify_ts() {
  if sed -E 's@/\*\s*debug\s+begin\s*\*/@/*@gi;s@/\*\s*debug\s+end\s*\*/@*/@gi;s@/\*\s*release\s+begin\s*\*/@@gi;s@/\*\s*release\s+end\s*\*/@@gi' < "$1.ts" > "build/$1.ts" \
  && tsc --removeComments --outFile "build/$1.tmp.js" "build/$1.ts" \
  && minify "build/$1.tmp.js" > "build/$1.js" \
  && rm -f "build/$1.ts" "build/$1.tmp.js"
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
mkdir -p dist/debug/ || exit 1

version=$(grep -F '"version": "' manifest.json | grep -oE '[0-9]+(\.[0-9]+)+')
archive_base_name="fbclid-blocker-$(echo "$version" | sed -E 's/\./-/g')"
echo "building version $version:"

echo "copying source files"
cp *.ts build/src/ || exit 1
{
  cat store/firefox/README || exit 1
  echo
  echo "Version $version was built with:"
  os_version="$(
    systeminfo \
      | grep -E '^OS (Name|Version)' \
      | tr '\r\n' '  ' \
      | sed -E 's/^ *OS Name: +([^ ].+[^ ]) +OS Version: +([^ ].+[^ ]) *$/\1, \2/'
  )"
  echo "system:    $os_version"
  echo "bash:      $(bash --version | grep -F 'bash, version')"
  echo "node.js:   $(node.exe --version)"
  echo "npm:       v$(npm --version)"
  echo "typecript: $(tsc --version | sed -E 's/Version /v/')"
  echo "minify:    $(minify --version)"

} >> build/src/README

echo "packing source zip archive"
cd build/src/
7z a "$archive_base_name-source.zip" -- *.ts README > /dev/null 2>&1 || exit 1
cd ../../

if ! [ $debug ]
then mv "build/src/$archive_base_name-source.zip" dist/ || exit 1
fi

rm -rf build/*

echo "compiling typecript"
if [ $debug ]
then
  debug_compile_ts fbclid-blocker-fb || exit 1
  debug_compile_ts fbclid-blocker-nonfb || exit 1
else
  compile_minify_ts fbclid-blocker-fb || exit 1
  compile_minify_ts fbclid-blocker-nonfb || exit 1
fi

echo "copying add-on files"
minify fbclid-blocker.html > build/fbclid-blocker.html || exit 1
cp icon/*.png manifest.json build/ || exit 1

if [ $debug ]
then
  if [ -d "dist/debug/$archive_base_name/" ]
  then
    rm -rf dist/debug/$archive_base_name/* || exit 1
  else
    mkdir  "dist/debug/$archive_base_name/" || exit 1
  fi
  cd build/
  mv *.png *.js *.html *.json "../dist/debug/$archive_base_name/"
  cd ../
else
  echo "packing zip archive"
  cd build/
  7z a "$archive_base_name.zip" -- *.png *.js *.html *.json > /dev/null 2>&1 || exit 1
  cd ../
  mv "build/$archive_base_name.zip" dist/ || exit 1
fi

echo "done"

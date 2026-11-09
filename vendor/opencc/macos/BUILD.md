# macOS OpenCC static library

`libopencc.a` in this directory is a universal (`arm64` + `x86_64`) static archive
built from OpenCC 1.4.2 source and merged with the bundled `libmarisa.a`.

It is a **build-time asset only**: `src/macos/scripts/build-app.sh` links it
directly into the app executable, so the resulting `.app` contains no `.dylib`
and needs no runtime extraction or cache directory.

## Prerequisites

- Xcode Command Line Tools: `xcode-select --install`
- CMake: `brew install cmake` (or a CMake.app on `PATH`)
- OpenCC 1.4.2 source checked out into `vendor/opencc-src/` (gitignored):

  ```bash
  git clone --branch ver.1.4.2 --depth 1 \
    https://github.com/BYVoid/OpenCC.git vendor/opencc-src
  ```

  Or point `OPENCC_SRC` at an existing checkout when running the script.

## Reproduce

1. Check out OpenCC at tag `ver.1.4.2` into `vendor/opencc-src/` (gitignored),
   or point `OPENCC_SRC` at an existing checkout.
2. Build and merge:

   ```bash
   bash src/macos/scripts/build-opencc.sh
   ```

3. Fill in the record table below and commit this file together with the
   regenerated `libopencc.a`.

## Build record

| Field | Value |
| --- | --- |
| OpenCC version | 1.4.2 |
| OpenCC commit | (fill in) |
| Build date | (fill in) |
| Xcode / Command Line Tools | (fill in) |
| macOS SDK | (fill in) |
| CMAKE_OSX_ARCHITECTURES | `arm64;x86_64` |
| CMAKE_OSX_DEPLOYMENT_TARGET | `14.0` |
| SHA256 | (fill in) |

## Why static

- One Mach-O inside the bundle: no `@rpath`, no `install_name_tool`, no
  library-validation issues during signing and notarization.
- The upstream CMake build already links marisa statically
  (`add_library(marisa STATIC ...)`), so merging the two archives yields a
  single self-contained `libopencc.a`.
- The jieba plugin is disabled (`BUILD_OPENCC_JIEBA_PLUGIN=OFF`) so no extra
  plugin dylib and no `dlopen` dependency is introduced.

## Licensing

OpenCC and its dictionaries are Apache-2.0; see `../LICENSE` and
`../NOTICE.txt`. The static archive is a build of that source and is covered
by the same license. The app ships copies of both files in
`Contents/Resources/`.

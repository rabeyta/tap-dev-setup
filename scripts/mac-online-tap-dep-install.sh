#!/bin/bash

## Versions we manage ##

# https://network.tanzu.vmware.com/products/tanzu-application-platform
TAP_VERSION=1.5.3
# https://github.com/tilt-dev/tilt/releases
TILT_VERSION=0.33.3
# https://github.com/buildpacks-community/kpack-cli/releases
KPACK_CLI_VERSION=0.11.0

## File Locations ##
TAP_FILE_LOCATION="$HOME/tanzu/tmp/$TAP_VERSION"
TAP_CLI_FILE_LOCATION="$HOME/tanzu/tmp/$TAP_VERSION/cli"

check_dependencies(){
    R=$1 && REQUIRED_DEPENDENCIES=${R[*]}
    MISSING_DEPENDENCIES=()

    for DEPENDENCY in ${REQUIRED_DEPENDENCIES}; do
        command -v "$DEPENDENCY" >/dev/null 2>&1 || { MISSING_DEPENDENCIES+=("$DEPENDENCY"); }
    done

    # Instead of exiting when we see a missing command, let's be nice and give the user a list.
    if [ ${#MISSING_DEPENDENCIES[@]} -ne 0 ]; then
        printf '> Missing %s, please install it!\n' "${MISSING_DEPENDENCIES[@]}"
        printf 'Exiting.\n'
        exit 1;
    fi
}

make_required_directories(){
  # hold tanzu
  mkdir -p "$TAP_FILE_LOCATION"
  mkdir -p "$TAP_CLI_FILE_LOCATION"
  # hold carvel
  mkdir -p "$HOME/carvel"
}

#https://network.tanzu.vmware.com/products/tanzu-application-platform
download_tap_release_files(){
  pivnet download-product-files \
  --product-slug='tanzu-application-platform' \
  --release-version=$TAP_VERSION \
  --glob="*tanzu*" \
  --download-dir="$TAP_FILE_LOCATION"
}

#https://docs.tilt.dev/install.html
download_tilt(){
  ARCH=$(uname -m)
  curl -fsSL https://github.com/tilt-dev/tilt/releases/download/v$TILT_VERSION/tilt.$TILT_VERSION.mac."$ARCH".tar.gz | tar -xzv tilt
  mv tilt "$TAP_CLI_FILE_LOCATION/tilt"
}

# carvel
# https://carvel.dev/
download_carvel(){
  export K14SIO_INSTALL_BIN_DIR=$TAP_CLI_FILE_LOCATION
  curl -L https://carvel.dev/install.sh | bash
}

#https://github.com/buildpacks-community/kpack-cli/releases
download_kpack(){
  case $(uname -m) in
    arm64)
      ARCH=arm64
      ;;
    x86_64)
      ARCH=amd64
      ;;
    *)
      ARCH=$(uname -m)
      ;;
  esac

  curl -fsSL https://github.com/buildpacks-community/kpack-cli/releases/download/v$KPACK_CLI_VERSION/kp-darwin-"$ARCH"-$KPACK_CLI_VERSION -o "$TAP_CLI_FILE_LOCATION/kp"
  chmod +x "$TAP_CLI_FILE_LOCATION/kp"
}


download_files(){
    download_tap_release_files
    download_tilt
    download_carvel
    download_kpack
}

install_dependency_vs_code_plugins(){
  # --force will install the latest if it isn't already installed
  code --install-extension vscjava.vscode-java-debug --force
  code --install-extension redhat.java --force
  code --install-extension redhat.vscode-yaml --force
}

install_tanzu_vs_code_plugin(){
  find "$TAP_FILE_LOCATION" -name "*.vsix" -print0 | while read -d $'\0' file
  do
    code --install-extension "$file"
  done
}

install_vs_code_plugins(){
  install_dependency_vs_code_plugins
  install_tanzu_vs_code_plugin
}

install_tanzu_cli(){
  TANZU_EXTRACTED_LOCATION="$TAP_FILE_LOCATION"/tanzu_framework
  # ensure directory
  mkdir -p "$TANZU_EXTRACTED_LOCATION"
  # untar
  find "$TAP_FILE_LOCATION" -name "tanzu-framework-darwin-amd64*" -print0 | while read -d $'\0' file
    do
      tar -xvf "$file" -C "$TANZU_EXTRACTED_LOCATION"
    done
  # move
  find "$TANZU_EXTRACTED_LOCATION" -name "tanzu-core-darwin*" -print0 | while read -d $'\0' file
    do
      mv "$file" "$TAP_CLI_FILE_LOCATION"/tanzu
    done
  # install plugins from downloaded tar
  export TANZU_CLI_NO_INIT=true
  pushd "$TANZU_EXTRACTED_LOCATION" || exit
  tanzu plugin install --local cli all
  popd
}

#TODO: start here
#update_path(){
#  if [ -n "$BASH_VERSION" ]; then
#    echo 'export PATH="$PATH:"' >> ~/.bash_profile
#  elif [ -n "$ZSH_VERSION" ]; then
#    echo 'export MY_VAR="my value"' >> ~/.zshrc
#  fi
#}

main(){
  check_dependencies "curl pivnet kubectl code javac"
  make_required_directories
  download_files
  install_vs_code_plugins
  install_tanzu_cli
#  install_intellij_plugin -> $ idea.sh install-plugin /path/to/plugin.zip
  # update path
}

main



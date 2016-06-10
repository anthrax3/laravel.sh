#!/bin/bash

{ # This ensures the entire script is downloaded

ROOT_UID=0
ARRAY_SEPARATOR="#"
OS=""
OS_VERSION=""
PROJECT=""
PACKAGE=""
UPDATE="false"
HTTPD_ROOT=""
SERVER=""

main() {
  welcome
  check_plataform
  update_plataform
  check_webserver
  check_git_installation
  check_git_config
  check_composer_installation
  create_project
  alter_composer
  alter_env
  path_permissions
  config
  success
}

welcome() {
  GREEN="$(tput setaf 2)"
  printf '%s' "$GREEN"
  printf '%s\n' '.____                                    .__              .__     '
  printf '%s\n' '|    |   _____ ____________ ___  __ ____ |  |        _____|  |__  '
  printf '%s\n' '|    |   \__  \\_  __ \__  \\  \/ // __ \|  |       /  ___/  |  \ '
  printf '%s\n' '|    |___ / __ \|  | \// __ \\   /\  ___/|  |__     \___ \|   Y  \'
  printf '%s\n' '|_______ (____  /__|  (____  /\_/  \___  >____/ /\ /____  >___|  /'
  printf '%s\n' '        \/    \/           \/          \/       \/      \/     \/ '
  printf '%s\n' 'Please look over the ~/.laravelrc file to select plugins, themes, and options.'
  printf '%s\n'
  printf '%s\n' 'p.s. Follow us at https://twitter.com/rbarros.'
  printf '%s\n' '------------------------------------------------------------------'
}

check_plataform() {
  step "Checking platform"

  # Detecting PLATFORM and ARCH
  UNAME="$(uname -a)"
  case "$UNAME" in
    Linux\ *)   PLATFORM=linux ;;
    Darwin\ *)  PLATFORM=darwin ;;
    SunOS\ *)   PLATFORM=sunos ;;
    FreeBSD\ *) PLATFORM=freebsd ;;
  esac
  case "$UNAME" in
    *x86_64*) ARCH=x64 ;;
    *i*86*)   ARCH=x86 ;;
    *armv6l*) ARCH=arm-pi ;;
  esac

  if [ -z $PLATFORM ] || [ -z $ARCH ]; then
    step_fail
    add_report "Cannot detect the current platform."
    fail
  fi

  step_done
  debug "Detected platform: $PLATFORM, $ARCH"

  if [ "$PLATFORM" = "linux" ]; then
    check_distro
  fi
}

check_distro() {
  step "Checking distro platform"
  # Detecting OS and OS_VERSION
  . /etc/os-release
  OS=$ID
  OS_VERSION=$VERSION_ID
  step_done
  debug "Detected distribution: $OS, $OS_VERSION"

  step "Get package distro"
  case ${OS} in
    ubuntu*)
      step_done
      #debug "detected Ubuntu ${OS_VERSION}"
      PACKAGE="apt-get"
      ;;
    debian*)
      step_done
      #debug "detected Debian ${OS_VERSION}"
      PACKAGE="apt-get"
      ;;
    centos*)
      step_done
      #debug "detected CentOS ${OS_VERSION}"
      PACKAGE="yum"
      ;;
    fedora*)
      step_done
      #debug "detected Fedora ${OS_VERSION}"
      PACKAGE="yum"
      ;;
    *)
      step_fail
      add_report "Cannot detect the current distro."
      fail
      ;;
  esac
}

update_plataform() {
  STOP=0
  trap abort_update INT

  debug "Will be update within 10 seconds."
  debug "To prevent its update, just press CTRL+C now."
  counter

  if [ "$STOP" = 0 ]; then
    step_wait "Update $OS, $OS_VERSION ..."
    if update_distro; then
      step_done
    fi
  fi

  trap - INT
}

abort_update() {
  STOP=1
  echo ""
  warn "laravel needs to be update."
}

update_distro() {
  super -v+ ${PACKAGE} -y update
}

check_webserver() {
  step "Checking webserver installation"
  step_done

  if command_exists apache2; then
    SERVER="apache2"
    #HTTPD_ROOT=$(awk '/DocumentRoot/ {print $2}' /etc/apache2/sites-enabled/000-default.conf)
    HTTPD_ROOT="/var/www/html"
  elif command_exists nginx; then
    SERVER="nginx"
    HTTPD_ROOT="/usr/share/nginx/html"
  fi
}

verlte() {
    [  "$1" = "`echo -e "$1\n$2" | sort -n | head -n1`" ]
}

verlt() {
    [ "$1" = "$2" ] && return 1 || verlte $1 $2
}

# git version 1.8.5.2 (Apple Git-48)
check() {
    return verlte git --version 1.0 && echo "yes" || echo "no"
}

check_git_installation() {
  step "Checking for Git installation"
  if command_exists git; then
    step_done
    debug "Git detected"
    check_git
  fi
}

check_git() {
  step "Checking version git"
  step_done
  if [ check = "yes" ]; then
    warn "version below 1.0"
    install_git
  else
    debug $(git --version)
  fi
}

install_git() {
  step_wait "Installing Git"
  if super ${PACKAGE} -y update git; then
    step_done
  else
    step_fail
    add_report "not installing git"
    fail
  fi
}

check_git_config() {
  username=$(git config user.name)
  if [ -z "$username" ]; then
    read -p "Informe o nome do usuário do bitbucket." username
    git config --global user.name "$username"
  else
    debug "Git user.name: $username"
  fi
  usermail=$(git config user.email)
  if [ -z "$usermail" ]; then
    read -p "Informe o email do usuário do bitbucket." useremail
    git config --global user.email $useremail
  else
    debug "Git user.mail: $useremail"
  fi
}

check_composer_installation() {
  step "Checking Composer installation"
  step_done

  fetch_cmd=$(curl_or_wget)
  if command_exists composer; then
    debug "Composer is installed, skipping Composer installation."
    debug "  To update Composer, run the command bellow:"
    debug "  $ composer self-update"
    update_composer
  else
    install_composer
  fi
}

update_composer() {
  step "Update composer"
  step_done
  super composer self-update
}

install_composer() {
  step "Installing composer"
  step_done
  if [ ! -f "composer.phar" ]; then
    curl -O https://getcomposer.org/composer.phar
  fi
  if comfirm "Move composer /usr/bin/composer ?"; then
      super mv composer.phar /usr/bin/composer
  fi
}

create_project() {
  step "Create a project laravel"
  step_done
  htdocs=""
  read -p "What the directory apache/nginx [$HTTPD_ROOT] ? " htdocs
  if [ "$htdocs" ]; then
    HTTPD_ROOT=$htdocs
  fi
  read -p "What is the project name ? " PROJECT
  if [ -z "$PROJECT" ]; then
    debug "The project name is required."
    create_project
  fi
  if [ ! -d "$PROJECT" ]; then
    cd $HTTPD_ROOT
    composer create-project --prefer-dist laravel/laravel $PROJECT
  else
    debug "The project [$PROJECT] already exists!"
    UPDATE="true"
    cd "$HTTPD_ROOT/$PROJECT"
  fi
}

alter_composer() {
  step "Changing the project composer"
  step_done
  install_jq
  cd "$HTTPD_ROOT/$PROJECT"
  if [ -f "composer.json" ]; then
    debug "Backup composer.json"
    if [ ! -f "composer.json.bkp" ]; then
        cp composer.json composer.json.bkp
        debug "Adding repository Core Saga in composer.json"
        if comfirm "This computer is configured for ssh access to bitbucket ?"; then
          REPO="git@bitbucket.org:sagaprojetosweb/core.git"
        else
          REPO="https://bitbucket.org/sagaprojetosweb/core.git"
        fi
        jq --arg repo "$REPO" '. + { "repositories": [{ "type": "git", "url": $repo }] }' composer.json > composer.temp && mv composer.temp composer.json
        jq '.["require-dev"] |= .+ {"sagaprojetosweb/core": "2.*"}' composer.json > composer.temp && mv composer.temp composer.json
        jq '.' composer.json
    fi
  else
    warn "composer.json not found"
  fi
}

install_jq() {
  step "Verifying that jq is installed"
  step_done
  if command_exists jq; then
    debug "jq is installed, skipping jq installation."
    debug $(jq --version)
  else
    debug "Installing jq"
    super -v+ ${PACKAGE} -y install jq
  fi
}

alter_env() {
  step "Changing the .env file project"
  step_done
  install_sed
  cd "$HTTPD_ROOT/$PROJECT"
  if [ -f ".env" ]; then
    read -p "DB_HOST [127.0.0.1]: " DB_HOST
    if [ -z "$DB_HOST" ]; then
      DB_HOST=127.0.0.1
    fi
    read -p "DB_DATABASE [homestead]: " DB_DATABASE
    if [ -z "$DB_DATABASE" ]; then
      DB_DATABASE=homestead
    fi
    read -p "DB_USERNAME [homestead]: " DB_USERNAME
    if [ -z "$DB_USERNAME" ]; then
      DB_USERNAME=homestead
    fi
    read -p "DB_PASSWORD []: " DB_PASSWORD
    #if [ -z "$DB_PASSWORD:[secret]" ]; then
      #DB_PASSWORD=secret
    #fi
    
    step "Create database project"
    if echo "create database $DB_DATABASE charset utf8;" | mysql -u $DB_USERNAME -p$DB_PASSWORD; then    # allowed to fail
        step_done
        debug "Database $DB_DATABASE created"
    else
        step_fail
        add_report "Database $DB_DATABASE not created"
        fail
    fi
    
    if [ ! -f ".env.bkp" ]; then
        debug "Backup .env"
        cp .env .env.bkp
        sed -i -e "s/\(DB_HOST=\).*/\1$DB_HOST/" \
           -e "s/\(DB_DATABASE=\).*/\1$DB_DATABASE/" \
           -e "s/\(DB_USERNAME=\).*/\1$DB_USERNAME/" \
           -e "s/\(DB_PASSWORD=\).*/\1$DB_PASSWORD/" .env
    fi
  else
    debug ".env not found"
  fi
}

install_sed() {
  step "Verifying that sed is installed"
  step_done
  if command_exists sed; then
    debug "sed already installed"
    #debug $(sed --version)
  else
    debug "Installing sed"
    super ${PACKAGE} -y install sed
  fi
}

path_permissions() {
  step "Changing permissions bootstrap/cache and storage"
  step_done
  if [ -d "$HTTPD_ROOT/$PROJECT" ]; then
    cd "$HTTPD_ROOT/$PROJECT"
    super chmod -R 777 bootstrap/cache
    super chmod -R 777 storage
  fi
}

config() {
  step "Project Setup"
  step_done
  HTTPD_ROOT=/home/ubuntu/workspace
  PROJECT=teste
  if [ -d "$HTTPD_ROOT/$PROJECT" ]; then
    cd "$HTTPD_ROOT/$PROJECT"
    if [ ! -f "config/app.bkp.php" ]; then
      debug "Backup do config/app.php"
      cp config/app.php config/app.bkp.php
      sed -i -e "s@RouteServiceProvider::class@RouteServiceProvider::class,\n\t\tCartalyst\\\Sentinel\\\Laravel\\\SentinelServiceProvider::class,\n\t\tPingpong\\\Modules\\\ModulesServiceProvider::class,\n\t\tTwigBridge\\\ServiceProvider::class,\n\t\tSaga\\\Core\\\ServiceProvider::class@g" config/app.php
      php artisan vendor:publish --provider="Saga\Core\ServiceProvider"
      php artisan vendor:publish --provider="Cartalyst\Sentinel\Laravel\SentinelServiceProvider"
      if [ -f "database/migrations/2014_10_12_000000_create_users_table.php" ]; then
          rm database/migrations/2014_10_12_000000_create_users_table.php
      fi
      if [ -f  "database/migrations/2014_10_12_100000_create_password_resets_table.php" ]; then
          rm database/migrations/2014_10_12_100000_create_password_resets_table.php
      fi
      php artisan migrate
    fi
  fi
}

counter() {
  for i in {0..10}; do
    echo -ne "$i"'\r';
    sleep 1;
    if [ "$STOP" = 1 ]; then
      break
    fi
  done; echo
}

comfirm() {
    text="$1 [y/N]"
    read -r -p "$text " response
    case $response in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}


curl_or_wget() {
  CURL_BIN="curl"; WGET_BIN="wget"
  if command_exists ${CURL_BIN}; then
    echo "${CURL_BIN} -sSL"
  elif command_exists ${WGET_BIN}; then
    echo "${WGET_BIN} -nv -O- -t 2 -T 10"
  fi
}

command_exists() {
  command -v "${@}" > /dev/null 2>&1
}

run_super() {
  if [ $(id -ru) != $ROOT_UID ]; then
    sudo "${@}"
  else
    "${@}"
  fi
}

super() {
  if [ "$1" = "-v" ]; then
    shift
    debug "${@}"
    run_super "${@}" > /dev/null
  elif echo "$1" | grep -P "\-v+"; then
    shift
    debug "${@}"
    run_super "${@}"
  else
    debug "${@}"
    run_super "${@}" > /dev/null 2>&1
  fi
}

atput() {
  [ -z "$TERM" ] && return 0
  eval "tput $@"
}

escape() {
  echo "$@" | sed "
    s/%{red}/$(atput setaf 1)/g;
    s/%{green}/$(atput setaf 2)/g;
    s/%{yellow}/$(atput setaf 3)/g;
    s/%{blue}/$(atput setaf 4)/g;
    s/%{magenta}/$(atput setaf 5)/g;
    s/%{cyan}/$(atput setaf 6)/g;
    s/%{white}/$(atput setaf 7)/g;
    s/%{reset}/$(atput sgr0)/g;
    s/%{[a-z]*}//g;
  "
}

log() {
  level="$1"; shift
  color=; stderr=; indentation=; tag=; opts=

  case "${level}" in
  debug)
    color="%{blue}"
    stderr=true
    indentation="  "
    ;;
  info)
    color="%{green}"
    ;;
  warn)
    color="%{yellow}"
    tag=" [WARN] "
    stderr=true
    ;;
  err)
    color="%{red}"
    tag=" [ERROR]"
  esac

  if [ "$1" = "-n" ]; then
    opts="-n"
    shift
  fi

  if [ "$1" = "-e" ]; then
    opts="$opts -e"
    shift
  fi

  if [ -z ${stderr} ]; then
    echo $opts "$(escape "${color}[laravel]${tag}%{reset} ${indentation}$@")"
  else
    echo $opts "$(escape "${color}[laravel]${tag}%{reset} ${indentation}$@")" 1>&2
  fi
}

step() {
  printf "$( log info $@ | sed -e :a -e 's/^.\{1,72\}$/&./;ta' )"
}

step_wait() {
  if [ ! -z "$@" ]; then
    STEP_WAIT="${@}"
    step "${STEP_WAIT}"
  fi
  echo "$(escape "%{blue}[ WAIT ]%{reset}")"
}

check_wait() {
  if [ ! -z "${STEP_WAIT}" ]; then
    step "${STEP_WAIT}"
    STEP_WAIT=
  fi
}

step_done() { check_wait && echo "$(escape "%{green}[ DONE ]%{reset}")"; }

step_warn() { check_wait && echo "$(escape "%{yellow}[ FAIL ]%{reset}")"; }

step_fail() { check_wait && echo "$(escape "%{red}[ FAIL ]%{reset}")"; }

debug() { log debug $@; }

info() { log info $@; }

warn() { log warn $@; }

err() { log err $@; }

add_report() {
  if [ -z "$report" ]; then
    report="${@}"
  else
    report="${report}${ARRAY_SEPARATOR}${@}"
  fi
}

fail() {
  echo ""
  IFS="${ARRAY_SEPARATOR}"
  add_report "Failed to install laravel."
  for report_message in $report; do
    err "$report_message"
  done
  exit 1
}

success() {
  echo ""
  IFS="${ARRAY_SEPARATOR}"
  if [ "${UPDATE}" = "true" ]; then
    add_report "laravel has been successfully updated."
  else
    add_report "laravel has been successfully installed."
  fi
  add_report '------------------------------------------------------------------'
  for report_message in $report; do
    info "$report_message"
  done
  exit 0
}

main "${@}"

} # This ensures the entire script is downloaded

#!/bin/bash

{ # This ensures the entire script is downloaded

ROOT_UID=0
ARRAY_SEPARATOR="#"
OS=""
OS_VERSION=""
PROJECT=""
PACKAGE=""

main() {
  check_plataform
  update
  check_git_installation
  check_git_config
  check_composer_installation
  #create_project
  #alter_composer
  #alter_env
  #path_permissions
  #config
  #laravel_install
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

  if [ -z $PLATFORM ] || [ -z $PLATFORM ]; then
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
      debug "detected Ubuntu ${OS_VERSION}"
      PACKAGE="apt-get"
      ;;
    debian*)
      step_done
      debug "detected Debian ${OS_VERSION}"
      PACKAGE="apt-get"
      ;;
    *)
      step_fail
      add_report "Cannot detect the current distro."
      fail
      ;;
  esac

  #if [ -e /etc/redhat-release ]; then
  #  RELEASE_RPM=$(rpm -qf /etc/redhat-release)
  #  RELEASE=$(rpm -q --qf '%{VERSION}' ${RELEASE_RPM})
  #  case ${RELEASE_RPM} in
  #    centos*)
  #      debug "detected CentOS ${RELEASE}"
  #      DISTRO="yum"
  #      PACKAGES="rpm -qa"
  #      ;;
  #    redhat*)
  #      debug "detected RHEL ${RELEASE}"
  #      ;;
  #    *)
  #      ;;
  #  esac
  #fi
}

update() {
  STOP=0
  trap abort_update SIGINT

  debug "Will be update within 10 seconds."
  debug "To prevent its update, just press CTRL+C now."
  counter

  if [ "$STOP" = 0 ]; then
    step_wait "Update $OS, $OS_VERSION ..."
    if update_distro; then
      step_done
    fi
  fi

  trap - SIGINT
}

abort_update() {
  STOP=1
  echo ""
  warn "laravel needs to be update."
}

update_distro() {
  super -v+ ${PACKAGE} -y update
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
  else
    git_install
  fi
}

git_install() {
  step_wait "Installing Git"
  if [ "${UPDATE_GIT}" = "true" ]  && \
     super ${PACKAGE} -y update git
     [ "${UPDATE_GIT}" != "true" ] && \
     super ${PACKAGE} -y update git; then
    step_done
  else
    step_fail
    add_report "${FAIL_TO_INSTALL_MSG}"
    fail
  fi
}

check_git_config() {
  username=$(git config user.name)
  if [ -z "$username" ]; then
    read -p "Informe o nome do usuário do bitbucket." username
    git config --global user.name "$username"
  else
    echo "Git user.name: $username"
  fi
  usermail=$(git config user.email)
  if [ -z "$usermail" ]; then
    read -p "Informe o email do usuário do bitbucket." useremail
    git config --global user.email $useremail
  else
    echo "Git user.mail: $useremail"
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
  else
    install_composer
  fi
}

install_composer() {
  step "Installing composer"
  step_done
  #echo "Instalando o composer"
  #sudo $distro -y install composer
  #php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
  #php -r "if (hash_file('SHA384', 'composer-setup.php') === '070854512ef404f16bac87071a6db9fd9721da1684cd4589b1196c3faf71b9a2682e2311b36a5079825e155ac7ce150d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
  #php composer-setup.php
  #php -r "unlink('composer-setup.php');"
  if [ ! -f "composer.phar" ]; then
    curl -O https://getcomposer.org/composer.phar
  fi
  read -p "Move composer /usr/bin/composer ?[Y/n]" bin
  if [ "$bin" = "y|Y" ]; then
    super mv composer.phar /usr/bin/composer
  fi
}

jq_install() {
  echo "Verificando se o jq esta instalado"
  JQ=$($PACKAGES | grep ^jq)
  if [ -z $($PACKAGES | grep ^jq) ]; then
    echo "Instalando o jq"
    sudo $distro -y install jq
  else
    echo "jq já instalado $JQ"
  fi
}

create_project() {
  echo "Criando o projeto em laravel"
  cd /var/www/html
  read -p "Qual o nome do projeto ?: " project
  if [ -z "$project" ]; then
    echo "O nome do projeto é obrigatório."
    create_project
  fi
  if [ ! -d "$project" ]; then
      php composer.phar create-project --prefer-dist laravel/laravel $project
  else
    echo "O projeto [$project] já existe"
  fi
}

alter_composer() {
  echo "Alterando o composer do projeto"
  jq_install
  cd /var/www/html/$project
  if [ -f "composer.json" ]; then
    echo "Backup do composer.json"
    cp composer.json composer.json.bkp
    echo "Adicionando repositorio do Saga Core no composer.json"
    jq '. + { "repositories": [{ "type": "git", "url": "https://bitbucket.org/sagaprojetosweb/core.git" }] }' composer.json > composer.temp && mv composer.temp composer.json
    jq '."require-dev" |= .+ {"sagaprojetosweb/core": "2.*"}' composer.json > composer.temp && mv composer.temp composer.json
    jq '.' composer.json
  else
    echo "composer.json não encontrado"
  fi
}

sed_install() {
  echo "Verificando se o sed esta instalado"
  SED=$($PACKAGES | grep ^sed)
  if [ -z "SED" ]; then
    echo "Instalando o sed"
    sudo $distro -y install sed
  else
    echo "sed já instalado $SED"
  fi
}

alter_env() {
  echo "Alterando o arquivo .env do projeto"
  sed_install
  cd /var/www/html/$project
  if [ -f ".env" ]; then
    echo "Backup do .env"
    cp .env .env.bkp
    read -p "Informe o DB_HOST:[127.0.0.1]" DB_HOST
    if [ -z "$DB_HOST" ]; then
      DB_HOST=127.0.0.1
    fi
    read -p "Informe o DB_DATABASE: " DB_DATABASE
    if [ -z "$DB_DATABASE:[homestead]" ]; then
      DB_DATABASE=homestead
    fi
    read -p "Informe o DB_USERNAME: " DB_USERNAME
    if [ -z "$DB_USERNAME:[homestead]" ]; then
      DB_USERNAME=homestead
    fi
    read -p "Informe o DB_PASSWORD: " DB_PASSWORD
    #if [ -z "$DB_PASSWORD:[secret]" ]; then
      #DB_PASSWORD=secret
    #fi

    echo "create database $DB_DATABASE charset utf8;" | mysql -u $DB_USERNAME -p$DB_PASSWORD

    sed -i -e "s/\(DB_HOST=\).*/\1$DB_HOST/" \
           -e "s/\(DB_DATABASE=\).*/\1$DB_DATABASE/" \
           -e "s/\(DB_USERNAME=\).*/\1$DB_USERNAME/" \
           -e "s/\(DB_PASSWORD=\).*/\1$DB_PASSWORD/" .env
  else
    echo ".env não encontrado"
  fi
}

path_permissions() {
  echo "Alterando permissões do bootstrap/cache e storage"
  cd /var/www/html/$project
  if [ -d "/var/www/html/$project" ]; then
    chmod -R 777 bootstrap/cache
    chmod -R 777 storage
  fi
}

config() {
  echo "Configuração do projeto"
  cd /var/www/html/$project
  if [ -d "/var/www/html/$project" ]; then
    echo "Backup do config/app.php"
    #cp config/app.php config/app.bkp.php
    #sed -i -e "s@RouteServiceProvider::class@RouteServiceProvider::class,\n\t\tCartalyst\Sentinel\Laravel\SentinelServiceProvider::class,\n\t\tPingpong\Modules\ModulesServiceProvider::class,\n\t\tTwigBridge\ServiceProvider::class,\n\t\tSaga\Core\ServiceProvider::class@g" config/app.php
    php artisan vendor:publish --provider="Cartalyst\Sentinel\Laravel\SentinelServiceProvider"
    rm database/migrations/2014_10_12_000000_create_users_table.php
    rm database/migrations/2014_10_12_100000_create_password_resets_table.php
    php artisan migrate
    php artisan vendor:publish --provider="Saga\Core\ServiceProvider"
  fi
}

laravel_install() {
  echo "Atualizando o composer"
  cd /var/www/html
  cp composer.phar $project/composer.phar
  if [ -d "$project" ]; then
    cd $project
    php composer.phar install
  fi
}

counter() {
  for i in {0..5}; do
    echo -ne "$i"'\r';
    sleep 1;
    if [ "$STOP" = 1 ]; then
      break
    fi
  done; echo
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
  if [ "${UPDATE_laravel}" = "true" ]; then
    add_report "laravel has been successfully updated."
    add_report 'Restart `laravel agent` in order for changes to take effect.'
  else
    add_report "laravel has been successfully installed."
  fi
  for report_message in $report; do
    info "$report_message"
  done
  exit 0
}

main "${@}"

} # This ensures the entire script is downloaded

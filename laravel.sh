#!/bin/bash

project=""
distro="yum"
packages="rpm -qa"

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

update() {
  echo "Atualizando servidor..."
  sudo $distro -y update
}

git_install() {
  echo "Verificando se o git esta instalado"
  GIT=$($packages | grep ^git)
  if [ -z "$GIT" ]; then
    echo "Instalando o git"
    sudo $distro -y install git
  else
    echo "git já instalado $GIT"
  fi
  if [ check == "yes" ]; then
    echo "Git não instalado ou version inferior a 1.0"
    echo "Instalando o git"
    sudo $distro -y install git
  fi
}

git_config() {
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

composer_install() {
  echo "Verificando se o composer esta instalado"
  #COMPOSER=$($packages | grep ^composer)
  if [ -z $($packages | grep composer) ]; then
    #echo "Instalando o composer"
    #sudo $distro -y install composer
    #php -r "copy('https://getcomposer.org/installer', 'composer-setup.php');"
    #php -r "if (hash_file('SHA384', 'composer-setup.php') === '070854512ef404f16bac87071a6db9fd9721da1684cd4589b1196c3faf71b9a2682e2311b36a5079825e155ac7ce150d') { echo 'Installer verified'; } else { echo 'Installer corrupt'; unlink('composer-setup.php'); } echo PHP_EOL;"
    #php composer-setup.php
    #php -r "unlink('composer-setup.php');"
    echo "Baixando o composer"
    cd /var/www/html
    if [ ! -f "composer.phar" ]; then
      curl -O https://getcomposer.org/composer.phar
    else
      php composer.phar --version
    fi
  else
    echo "composer já instalado $COMPOSER"
  fi
}

jq_install() {
  echo "Verificando se o jq esta instalado"
  JQ=$($packages | grep ^jq)
  if [ -z $($packages | grep ^jq) ]; then
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
  SED=$($packages | grep ^sed)
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

if [[ -e /etc/redhat-release ]]; then
  RELEASE_RPM=$(rpm -qf /etc/redhat-release)
  RELEASE=$(rpm -q --qf '%{VERSION}' ${RELEASE_RPM})
  case ${RELEASE_RPM} in
    centos*)
      echo "detected CentOS ${RELEASE}"
      distro="yum"
      packages="rpm -qa"
      ;;
    redhat*)
      echo "detected RHEL ${RELEASE}"
      ;;
    *)
      DISTROID=$(cat /etc/*release /etc/*version | grep ^ID= | awk -F= '{print $2}')
      DISTROVERSION=$(cat /etc/*release /etc/*version | grep ^VERSION_ID= | awk -F= '{print $2}')
      ;;
  esac

  case ${DISTROID} in
    ubuntu*)
      echo "detected Ubuntu ${DISTROVERSION}"
      distro="apt-get"
      package='${binary:Package}\n'
      packages="dpkg-query -f $package -W"
      ;;
    debian*)
      echo "detected Debian ${DISTROVERSION}"
      ;;
    *)
      echo "unknown EL clone"
      exit 1
      ;;
  esac
  update
  git_install
  git_config
  composer_install
  create_project
  alter_composer
  alter_env
  path_permissions
  config
  laravel_install

else
  echo "not an EL distro"
  exit 1
fi

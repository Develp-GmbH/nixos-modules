#!@shell@

export PATH="@binPath@:${PATH}"

read -r -d '' HELP_MSG << EOM
NAME
    secret

SYNOPSIS
    secret [-v|--verbose] [-d|--debug] [-d|--decrypt] <-m|--machine>=host <-s|--service>=abc <-n|--secret-name>=token

EXAMPLE
    secret -v --machine=lido-mainnet-01 --service=cachix-deploy --secret=token
    secret -v --machine=lido-mainnet-01 --re-encrypt
    secret --re-encrypt-all

DESCRIPTION
    Secret is the command made for nix repos to get rid of the secret.nix when
    you are using agenix. Secret must be used with mcl-secrets and mcl-host-info
    modules from nixos-modules repository to work properly.

    By default, secrets are stored in machines/\${HOST}/secrets/service/
    if this directory exists, unless otherwise specified.

OPTIONS
    -f|--secrets-folder   - pecifies the location where secrets are saved.
    -m|--machine          - Machine for which you want to create a secret.
    -s|--service          - Service for which you want to create a secret.
    -n|--secret-name      - Secret you want to encrypt.
    -v|--vm               - Make secret for the vmVariant.
    -d|--decrypt          - Decrypt and print secret.
    -r|--re-encrypt       - Re-encrypt the secret.
    -a|--re-encrypt-all   - Re-encrypt secrets for all services for host."
    -V|--verbose          - Produce more verbose log messages.
    -D|--debug            - Show whole trace of this bash script.
    -h|--help             - Show this help message.
EOM

set -euo pipefail

function nix_eval_secrets() {
  target="${1}"
  shift
  machineName="${machine}"
  if [[ "${machineType}" == 'vm' ]]; then
    machineName="vm-${machineName}"
  fi
  nix eval ${@} ".#nixosConfigurations.\"${machineName}\".config.mcl.secrets.${target}"
}

function agenix_wrapper() {
  # Secrets folder is available in the secrets object in Nix.
  if [[ -z "${secretsFolder}" ]]; then
    local secretsFolder=$(
      nix_eval_secrets services.${service}.encryptedSecretDir --raw \
        | sed -r 's#/nix/store/[a-z0-9]+-(source|secrets)/?##'
    )
    # If path has no subfolders it must be that of defaults.
    if [[ -z "${secretsFolder}" ]]; then
      local secretsFolder="modules/default-${machineType}-config/secrets"
    fi
  fi
  # The Agenix secrets definition file is generated by Nix.
  export rulesFile="$(nix_eval_secrets "services.${service}.nix-file" --raw)"
  if [[ -z "${rulesFile}" ]]; then
    echo "ERROR: No Agenix rules file found!" >&2
    exit 1
  fi
  # Support providiing custom paths to Age identity files.
  if [[ -n "${AGE_IDENTITIES}" ]]; then
    export agenixArgs="-i $(echo "${AGE_IDENTITIES}" | sed -z '$ s/\n$//' | tr '\n' ' ' | sed -e 's/ / -i /g')"
  fi
  # Show what is being executed to the user.
  if [[ "${verbose}" == 'true' ]]; then
    agenixArgs="-v ${agenixArgs}"
    echo -e "{\n  cd ${secretsFolder}/${service};\n  ln -s ${rulesFile} secrets.nix;\n  agenix ${agenixArgs} ${@};\n  unlink secrets.nix;\n}" >&2
  fi

  pushd "${secretsFolder}/${service}" >/dev/null

  # Required due to: https://github.com/yaxitech/ragenix/issues/160
  ln -fs "${rulesFile}" secrets.nix
  trap "unlink ${PWD}/secrets.nix" RETURN

  agenix ${agenixArgs} ${@};
  popd >/dev/null
}

machine=""
service=""
secret=""
debug=false
verbose=false
machineType=server
decrypt=false
reEncrypt=false
reEncryptAll=false
secretsFolder=""

parsedFlags=$(
    getopt \
        -o 'f:,m:,s:,n:,v,d,r,a,V,D,h' \
        -l 'secrets-folder:,machine:,service:,secret-name:,vm,decrypt,re-encrypt,re-encrypt-all,verbose,debug,help' \
        -n 'secret' -- "${@}"
)
[[ $? -ne 0 ]] && { echo "Failed to parse options" >&2; exit 1; }
eval set -- "${parsedFlags}"

while true; do
    case "${1}" in
        -f|--secrets-folder=*)  secretsFolder="${2}"; shift 2;;
        -m|--machine=*)         machine="${2}";       shift 2;;
        -s|--service=*)         service="${2}";       shift 2;;
        -n|--secret-name=*)     secretName="${2}";    shift 2;;
        -v|--vm)                machineType=vm;       shift;;
        -d|--decrypt)           decrypt=true;         shift;;
        -r|--re-encrypt)        reEncrypt=true;       shift;;
        -a|--re-encrypt-all)    reEncryptAll=true;    shift;;
        -V|--verbose)           verbose=true;         shift;;
        -D|--debug)             debug=true;           shift;;
        -h|--help)              echo "${HELP_MSG}";   exit 0;;
        --)                     shift;                break;;
        *)                      echo "UNKNOWN: $1";   exit 1;;
    esac
done

# Enable debug bash tracing.
if [[ "${debug}" == true ]]; then
    set -x
fi

if [[ "${reEncryptAll}" == true && -z "${machine}" ]]; then
  echo "You must specify machine"; exit 1
elif [[ "${reEncrypt}" == true && (-z "${machine}" || -z "${service}") ]]; then
  echo "You must specify machine and service"; exit 1
elif [[ "${reEncrypt}" == false && "${reEncryptAll}" == false && (-z "${machine}" || -z "${service}" || -z "${secretName}") ]]; then
  echo "You must specify machine, service, and secret"; exit 1
fi

if [[ "${reEncryptAll}" == true ]]; then
  for service in $(nix_eval_secrets "services" --apply builtins.attrNames --json | jq -r '.[]'); do
    echo "Re-encripting secrets for: ${service}"
    agenix_wrapper -r
  done
else
  if [[ "${reEncrypt}" == true ]]; then
    agenix_wrapper -r
  elif [[ "${decrypt}" == true ]]; then
    agenix_wrapper -d "${secretName}.age"
  else
    agenix_wrapper -e "${secretName}.age"
  fi
fi

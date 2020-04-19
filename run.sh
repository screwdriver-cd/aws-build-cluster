#!/bin/bash
set -eo pipefail

CWD=$(dirname ${BASH_SOURCE})

declare -r deps=(jq yq envsubst aws eksctl kubectl helm)
declare -r install_docs=(
    'https://github.com/stedolan/jq/releases/latest'
    'https://github.com/mikefarah/yq/releases/latest'
    'https://www.gnu.org/software/gettext/'
    'https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html'
    'https://github.com/weaveworks/eksctl/#installation'
    'https://kubernetes.io/docs/tasks/tools/install-kubectl'
    'https://helm.sh/docs/intro/install/'
)

for ((i = 0, f = 0; i < ${#deps[@]}; i++)); do
    if ! command -v ${deps[$i]} &>/dev/null; then
        ((++f)) && echo "'${deps[$i]}' command is not found. Please refer to ${install_docs[$i]} for proper installation."
    fi
done

if [[ $f -ne 0 ]]; then
    exit 127
fi

inject_env_from_config() {
    yq r -j $1 | jq -r 'def spread(v): v | keys[] as $k | .[$k] | if (.|type == "object") then to_entries | .[] | if (.value|type == "object") and (.value|keys|all(test("^[A-Z_]+$"))) then spread({ ($k + "_" + .key): .value }) else "export \($k)_\(.key)=\(.value)" end else "export \($k)=\(.)" end; spread(.)'
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -s|--scripts)
            scripts=($(tr ',' ' ' <<< $2))
            shift 2
            ;;
        -*)
            echo "Unkown flag" $1
            exit 1
            ;;
        *)
            if [[ -n $config_file ]]; then
                echo "Unknown argument" $1
                exit 1
            fi

            config_file=$1
            shift
            ;;
    esac
done

`inject_env_from_config ${config_file:-./config.yaml}`

for script in ${scripts[@]:-$(ls $CWD/scripts/*)}; do
    echo "Executing:" $script
    source "$script"
done

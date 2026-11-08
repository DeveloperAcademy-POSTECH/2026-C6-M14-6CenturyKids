set -eu

: "${SUPABASE_URL:?SUPABASE_URL is missing}"
: "${SUPABASE_ANON_KEY:?SUPABASE_ANON_KEY is missing}"
: "${KAKAO_NATIVE_APP_KEY:?KAKAO_NATIVE_APP_KEY is missing}"
: "${AMPLITUDE_API_KEY:?AMPLITUDE_API_KEY is missing}"

mkdir -p "$CI_PRIMARY_REPOSITORY_PATH/Configuration"

write_setting() {
    printf '%s = %s\n' "$1" "$2" | sed 's#//#/$()/#g'
}

{
    write_setting SUPABASE_URL "$SUPABASE_URL"
    write_setting SUPABASE_ANON_KEY "$SUPABASE_ANON_KEY"
    write_setting KAKAO_NATIVE_APP_KEY "$KAKAO_NATIVE_APP_KEY"
    write_setting AMPLITUDE_API_KEY "$AMPLITUDE_API_KEY"
} > "$CI_PRIMARY_REPOSITORY_PATH/Configuration/Secrets.xcconfig"

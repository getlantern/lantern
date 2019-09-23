#!/bin/bash

INPUT=$1
OUTPUT=$2

types=""
keys=""
rels=""
abss=""
sws=""
mscs=""
leds=""
reps=""
snds=""
ffstatuss=""

while read LINE; do
    tab=$'\t'
    space="[ ${tab}]"
    regex="^#define ((EV|KEY|BTN|REL|ABS|SW|MSC|LED|REP|SND|FF_STATUS)_[A-Z0-9_]+)${space}"
    if [[ $LINE =~ $regex ]]; then
        type=${BASH_REMATCH[2]}
        name=${BASH_REMATCH[1]}
        if [[ $type = "EV" ]]; then
            if [[ $name != "EV_VERSION" ]]; then
                types="${types}    [${name}] = \"${name}\",
"
            fi
        elif [[ $type = "KEY" ]] || [[ $type = "BTN" ]]; then
            if [[ $name != "KEY_MIN_INTERESTING" ]]; then
                keys="${keys}    [${name}] = \"${name}\",
"
            fi
        elif [[ $type = "REL" ]]; then
            rels="${rels}    [${name}] = \"${name}\",
"
        elif [[ $type = "ABS" ]]; then
            abss="${abss}    [${name}] = \"${name}\",
"
        elif [[ $type = "SW" ]]; then
            sws="${sws}    [${name}] = \"${name}\",
"
        elif [[ $type = "MSC" ]]; then
            mscs="${mscs}    [${name}] = \"${name}\",
"
        elif [[ $type = "LED" ]]; then
            leds="${leds}    [${name}] = \"${name}\",
"
        elif [[ $type = "REP" ]]; then
            reps="${reps}    [${name}] = \"${name}\",
"
        elif [[ $type = "SND" ]]; then
            snds="${snds}    [${name}] = \"${name}\",
"
        elif [[ $type = "FF_STATUS" ]]; then
            ffstatuss="${ffstatuss}    [${name}] = \"${name}\",
"
        fi
    fi
done < "${INPUT}"

(
echo "
static const char *type_names[] = {
${types}};

static const char *key_names[] = {
${keys}};

static const char *rel_names[] = {
${rels}};

static const char *abs_names[] = {
${abss}};

static const char *sw_names[] = {
${sws}};

static const char *msc_names[] = {
${mscs}};

static const char *led_names[] = {
${leds}};

static const char *rep_names[] = {
${reps}};

static const char *snd_names[] = {
${snds}};

static const char *ffstatus_names[] = {
${ffstatuss}};
"
) >"${OUTPUT}"

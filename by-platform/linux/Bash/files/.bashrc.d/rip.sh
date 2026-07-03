#!/usr/bin/env bash

# dvd-decrypt [<device>]
function dvd-decrypt() {
    dvdbackup -I -i "${1:-/dev/cdrom}"
}

# dvd-rip [<device>]
function dvd-rip() {
    local dev=${1:-/dev/cdrom} \
        type record code flags count header id index \
        TCOUNT CINFO TINFO
    dev=$(realpath "$dev") &&
        lk_mktemp_with CINFO printf '%s,%s,%s\n' id code value &&
        lk_mktemp_with TINFO printf '%s,%s,%s,%s\n' index id code value || return
    dvd-decrypt "$dev" || return

    local ap_ia=()
    ap_ia[0]=Unknown
    ap_ia[1]=Type
    ap_ia[2]=Name
    ap_ia[3]=LangCode
    ap_ia[4]=LangName
    ap_ia[5]=CodecId
    ap_ia[6]=CodecShort
    ap_ia[7]=CodecLong
    ap_ia[8]=ChapterCount
    ap_ia[9]=Duration
    ap_ia[10]=DiskSize
    ap_ia[11]=DiskSizeBytes
    ap_ia[12]=StreamTypeExtension
    ap_ia[13]=Bitrate
    ap_ia[14]=AudioChannelsCount
    ap_ia[15]=AngleInfo
    ap_ia[16]=SourceFileName
    ap_ia[17]=AudioSampleRate
    ap_ia[18]=AudioSampleSize
    ap_ia[19]=VideoSize
    ap_ia[20]=VideoAspectRatio
    ap_ia[21]=VideoFrameRate
    ap_ia[22]=StreamFlags
    ap_ia[23]=DateTime
    ap_ia[24]=OriginalTitleId
    ap_ia[25]=SegmentsCount
    ap_ia[26]=SegmentsMap
    ap_ia[27]=OutputFileName
    ap_ia[28]=MetadataLanguageCode
    ap_ia[29]=MetadataLanguageName
    ap_ia[30]=TreeInfo
    ap_ia[31]=PanelTitle
    ap_ia[32]=VolumeName
    ap_ia[33]=OrderWeight
    ap_ia[34]=OutputFormat
    ap_ia[35]=OutputFormatDescription
    ap_ia[36]=SeamlessInfo
    ap_ia[37]=PanelText
    ap_ia[38]=MkvFlags
    ap_ia[39]=MkvFlagsText
    ap_ia[40]=AudioChannelLayoutName
    ap_ia[41]=OutputCodecShort
    ap_ia[42]=OutputConversionType
    ap_ia[43]=OutputAudioSampleRate
    ap_ia[44]=OutputAudioSampleSize
    ap_ia[45]=OutputAudioChannelsCount
    ap_ia[46]=OutputAudioChannelLayoutName
    ap_ia[47]=OutputAudioChannelLayout
    ap_ia[48]=OutputAudioMixDescription
    ap_ia[49]=Comment
    ap_ia[50]=OffsetSequenceId

    while IFS=: read -r type record; do
        case "$type" in
        MSG)
            IFS=, read -r code flags count record <<<"$record"
            header=$(
                printf '%s' message
                printf ',%s' format
                for ((i = 0; i < count; i++)); do
                    printf ',param%d' $i
                done
            )
            printf '%s\n' "$header" "$record" |
                csvjson --stream |
                jq -r .message
            ;;
        TCOUNT)
            TCOUNT=$((record))
            ;;
        CINFO)
            IFS=, read -r id code record <<<"$record"
            printf '%s,%s,%s\n' "${ap_ia[id]-Unknown}" "$code" "$record" >>"$CINFO"
            ;;
        TINFO)
            IFS=, read -r index id code record <<<"$record"
            printf '%s,%s,%s,%s\n' "$index" "${ap_ia[id]-Unknown}" "$code" "$record" >>"$TINFO"
            ;;
        esac
    done < <(makemkvcon -r info "dev:$dev")

    lk_tty_print 'Titles:' $TCOUNT
    csvjson --stream --no-inference "$CINFO" |
        jq -s '[.[] | {"\(.id)": .value}] | add'
    csvjson --stream --no-inference "$TINFO" |
        jq -s 'group_by(.index)[] | ({"title_index": .[0].index} + ([.[] | {"\(.id)": .value}] | add))'
    # - provide list of titles with chapter count and duration
    # - get titles to rip
    # - get name of disc for renaming
    # - `makemkvcon -r mkv "dev:$dev" "$title_index" "$target"`
    # - rename output files
}

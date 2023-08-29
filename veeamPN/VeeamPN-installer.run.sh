#!/bin/sh
# This script was generated using Makeself 2.3.0

ORIG_UMASK=`umask`
if test "n" = n; then
    umask 077
fi

CRCsum="3426762719"
MD5="bb84ff32ede8ba3713474392ec3c6c33"
TMPROOT=${TMPDIR:=/tmp}
USER_PWD="$PWD"; export USER_PWD

label="Veeam PN installer"
script="./startup.sh"
scriptargs=""
licensetxt=""
helpheader=''
targetdir="makeself-1-20201217182601"
filesizes="55335"
keep="n"
nooverwrite="n"
quiet="n"

print_cmd_arg=""
if type printf > /dev/null; then
    print_cmd="printf"
elif test -x /usr/ucb/echo; then
    print_cmd="/usr/ucb/echo"
else
    print_cmd="echo"
fi

unset CDPATH

MS_Printf()
{
    $print_cmd $print_cmd_arg "$1"
}

MS_PrintLicense()
{
  if test x"$licensetxt" != x; then
    echo "$licensetxt"
    while true
    do
      MS_Printf "Please type y to accept, n otherwise: "
      read yn
      if test x"$yn" = xn; then
        keep=n
	eval $finish; exit 1
        break;
      elif test x"$yn" = xy; then
        break;
      fi
    done
  fi
}

MS_diskspace()
{
	(
	if test -d /usr/xpg4/bin; then
		PATH=/usr/xpg4/bin:$PATH
	fi
	df -kP "$1" | tail -1 | awk '{ if ($4 ~ /%/) {print $3} else {print $4} }'
	)
}

MS_dd()
{
    blocks=`expr $3 / 1024`
    bytes=`expr $3 % 1024`
    dd if="$1" ibs=$2 skip=1 obs=1024 conv=sync 2> /dev/null | \
    { test $blocks -gt 0 && dd ibs=1024 obs=1024 count=$blocks ; \
      test $bytes  -gt 0 && dd ibs=1 obs=1024 count=$bytes ; } 2> /dev/null
}

MS_dd_Progress()
{
    if test x"$noprogress" = xy; then
        MS_dd $@
        return $?
    fi
    file="$1"
    offset=$2
    length=$3
    pos=0
    bsize=4194304
    while test $bsize -gt $length; do
        bsize=`expr $bsize / 4`
    done
    blocks=`expr $length / $bsize`
    bytes=`expr $length % $bsize`
    (
        dd ibs=$offset skip=1 2>/dev/null
        pos=`expr $pos \+ $bsize`
        MS_Printf "     0%% " 1>&2
        if test $blocks -gt 0; then
            while test $pos -le $length; do
                dd bs=$bsize count=1 2>/dev/null
                pcent=`expr $length / 100`
                pcent=`expr $pos / $pcent`
                if test $pcent -lt 100; then
                    MS_Printf "\b\b\b\b\b\b\b" 1>&2
                    if test $pcent -lt 10; then
                        MS_Printf "    $pcent%% " 1>&2
                    else
                        MS_Printf "   $pcent%% " 1>&2
                    fi
                fi
                pos=`expr $pos \+ $bsize`
            done
        fi
        if test $bytes -gt 0; then
            dd bs=$bytes count=1 2>/dev/null
        fi
        MS_Printf "\b\b\b\b\b\b\b" 1>&2
        MS_Printf " 100%%  " 1>&2
    ) < "$file"
}

MS_Help()
{
    cat << EOH >&2
${helpheader}Makeself version 2.3.0
 1) Getting help or info about $0 :
  $0 --help   Print this message
  $0 --info   Print embedded info : title, default target directory, embedded script ...
  $0 --lsm    Print embedded lsm entry (or no LSM)
  $0 --list   Print the list of files in the archive
  $0 --check  Checks integrity of the archive

 2) Running $0 :
  $0 [options] [--] [additional arguments to embedded script]
  with following options (in that order)
  --confirm             Ask before running embedded script
  --quiet		Do not print anything except error messages
  --noexec              Do not run embedded script
  --keep                Do not erase target directory after running
			the embedded script
  --noprogress          Do not show the progress during the decompression
  --nox11               Do not spawn an xterm
  --nochown             Do not give the extracted files to the current user
  --target dir          Extract directly to a target directory
                        directory path can be either absolute or relative
  --tar arg1 [arg2 ...] Access the contents of the archive through the tar command
  --                    Following arguments will be passed to the embedded script
EOH
}

MS_Check()
{
    OLD_PATH="$PATH"
    PATH=${GUESS_MD5_PATH:-"$OLD_PATH:/bin:/usr/bin:/sbin:/usr/local/ssl/bin:/usr/local/bin:/opt/openssl/bin"}
	MD5_ARG=""
    MD5_PATH=`exec <&- 2>&-; which md5sum || command -v md5sum || type md5sum`
    test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which md5 || command -v md5 || type md5`
	test -x "$MD5_PATH" || MD5_PATH=`exec <&- 2>&-; which digest || command -v digest || type digest`
    PATH="$OLD_PATH"

    if test x"$quiet" = xn; then
		MS_Printf "Verifying archive integrity..."
    fi
    offset=`head -n 522 "$1" | wc -c | tr -d " "`
    verb=$2
    i=1
    for s in $filesizes
    do
		crc=`echo $CRCsum | cut -d" " -f$i`
		if test -x "$MD5_PATH"; then
			if test x"`basename $MD5_PATH`" = xdigest; then
				MD5_ARG="-a md5"
			fi
			md5=`echo $MD5 | cut -d" " -f$i`
			if test x"$md5" = x00000000000000000000000000000000; then
				test x"$verb" = xy && echo " $1 does not contain an embedded MD5 checksum." >&2
			else
				md5sum=`MS_dd_Progress "$1" $offset $s | eval "$MD5_PATH $MD5_ARG" | cut -b-32`;
				if test x"$md5sum" != x"$md5"; then
					echo "Error in MD5 checksums: $md5sum is different from $md5" >&2
					exit 2
				else
					test x"$verb" = xy && MS_Printf " MD5 checksums are OK." >&2
				fi
				crc="0000000000"; verb=n
			fi
		fi
		if test x"$crc" = x0000000000; then
			test x"$verb" = xy && echo " $1 does not contain a CRC checksum." >&2
		else
			sum1=`MS_dd_Progress "$1" $offset $s | CMD_ENV=xpg4 cksum | awk '{print $1}'`
			if test x"$sum1" = x"$crc"; then
				test x"$verb" = xy && MS_Printf " CRC checksums are OK." >&2
			else
				echo "Error in checksums: $sum1 is different from $crc" >&2
				exit 2;
			fi
		fi
		i=`expr $i + 1`
		offset=`expr $offset + $s`
    done
    if test x"$quiet" = xn; then
		echo " All good."
    fi
}

UnTAR()
{
    if test x"$quiet" = xn; then
		tar $1vf - 2>&1 || { echo Extraction failed. > /dev/tty; kill -15 $$; }
    else

		tar $1f - 2>&1 || { echo Extraction failed. > /dev/tty; kill -15 $$; }
    fi
}

finish=true
xterm_loop=
noprogress=n
nox11=n
copy=none
ownership=y
verbose=n

initargs="$@"

while true
do
    case "$1" in
    -h | --help)
	MS_Help
	exit 0
	;;
    -q | --quiet)
	quiet=y
	noprogress=y
	shift
	;;
    --info)
	echo Identification: "$label"
	echo Target directory: "$targetdir"
	echo Uncompressed size: 44 KB
	echo Compression: base64
	echo Date of packaging: Thu Dec 17 18:26:01 UTC 2020
	echo Built with Makeself version 2.3.0 on 
	echo Build command was: "/usr/bin/makeself \\
    \"--base64\" \\
    \".\" \\
    \"VeeamPN-installer.run.sh\" \\
    \"Veeam PN installer\" \\
    \"./startup.sh\""
	if test x"$script" != x; then
	    echo Script run after extraction:
	    echo "    " $script $scriptargs
	fi
	if test x"" = xcopy; then
		echo "Archive will copy itself to a temporary location"
	fi
	if test x"n" = xy; then
		echo "Root permissions required for extraction"
	fi
	if test x"n" = xy; then
	    echo "directory $targetdir is permanent"
	else
	    echo "$targetdir will be removed after extraction"
	fi
	exit 0
	;;
    --dumpconf)
	echo LABEL=\"$label\"
	echo SCRIPT=\"$script\"
	echo SCRIPTARGS=\"$scriptargs\"
	echo archdirname=\"makeself-1-20201217182601\"
	echo KEEP=n
	echo NOOVERWRITE=n
	echo COMPRESS=base64
	echo filesizes=\"$filesizes\"
	echo CRCsum=\"$CRCsum\"
	echo MD5sum=\"$MD5\"
	echo OLDUSIZE=44
	echo OLDSKIP=523
	exit 0
	;;
    --lsm)
cat << EOLSM
No LSM.
EOLSM
	exit 0
	;;
    --list)
	echo Target directory: $targetdir
	offset=`head -n 522 "$0" | wc -c | tr -d " "`
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "base64 -d -i" | UnTAR t
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
	--tar)
	offset=`head -n 522 "$0" | wc -c | tr -d " "`
	arg1="$2"
    if ! shift 2; then MS_Help; exit 1; fi
	for s in $filesizes
	do
	    MS_dd "$0" $offset $s | eval "base64 -d -i" | tar "$arg1" - "$@"
	    offset=`expr $offset + $s`
	done
	exit 0
	;;
    --check)
	MS_Check "$0" y
	exit 0
	;;
    --confirm)
	verbose=y
	shift
	;;
	--noexec)
	script=""
	shift
	;;
    --keep)
	keep=y
	shift
	;;
    --target)
	keep=y
	targetdir=${2:-.}
    if ! shift 2; then MS_Help; exit 1; fi
	;;
    --noprogress)
	noprogress=y
	shift
	;;
    --nox11)
	nox11=y
	shift
	;;
    --nochown)
	ownership=n
	shift
	;;
    --xwin)
	if test "n" = n; then
		finish="echo Press Return to close this window...; read junk"
	fi
	xterm_loop=1
	shift
	;;
    --phase2)
	copy=phase2
	shift
	;;
    --)
	shift
	break ;;
    -*)
	echo Unrecognized flag : "$1" >&2
	MS_Help
	exit 1
	;;
    *)
	break ;;
    esac
done

if test x"$quiet" = xy -a x"$verbose" = xy; then
	echo Cannot be verbose and quiet at the same time. >&2
	exit 1
fi

if test x"n" = xy -a `id -u` -ne 0; then
	echo "Administrative privileges required for this archive (use su or sudo)" >&2
	exit 1	
fi

if test x"$copy" \!= xphase2; then
    MS_PrintLicense
fi

case "$copy" in
copy)
    tmpdir=$TMPROOT/makeself.$RANDOM.`date +"%y%m%d%H%M%S"`.$$
    mkdir "$tmpdir" || {
	echo "Could not create temporary directory $tmpdir" >&2
	exit 1
    }
    SCRIPT_COPY="$tmpdir/makeself"
    echo "Copying to a temporary location..." >&2
    cp "$0" "$SCRIPT_COPY"
    chmod +x "$SCRIPT_COPY"
    cd "$TMPROOT"
    exec "$SCRIPT_COPY" --phase2 -- $initargs
    ;;
phase2)
    finish="$finish ; rm -rf `dirname $0`"
    ;;
esac

if test x"$nox11" = xn; then
    if tty -s; then                 # Do we have a terminal?
	:
    else
        if test x"$DISPLAY" != x -a x"$xterm_loop" = x; then  # No, but do we have X?
            if xset q > /dev/null 2>&1; then # Check for valid DISPLAY variable
                GUESS_XTERMS="xterm gnome-terminal rxvt dtterm eterm Eterm xfce4-terminal lxterminal kvt konsole aterm terminology"
                for a in $GUESS_XTERMS; do
                    if type $a >/dev/null 2>&1; then
                        XTERM=$a
                        break
                    fi
                done
                chmod a+x $0 || echo Please add execution rights on $0
                if test `echo "$0" | cut -c1` = "/"; then # Spawn a terminal!
                    exec $XTERM -title "$label" -e "$0" --xwin "$initargs"
                else
                    exec $XTERM -title "$label" -e "./$0" --xwin "$initargs"
                fi
            fi
        fi
    fi
fi

if test x"$targetdir" = x.; then
    tmpdir="."
else
    if test x"$keep" = xy; then
	if test x"$nooverwrite" = xy && test -d "$targetdir"; then
            echo "Target directory $targetdir already exists, aborting." >&2
            exit 1
	fi
	if test x"$quiet" = xn; then
	    echo "Creating directory $targetdir" >&2
	fi
	tmpdir="$targetdir"
	dashp="-p"
    else
	tmpdir="$TMPROOT/selfgz$$$RANDOM"
	dashp=""
    fi
    mkdir $dashp $tmpdir || {
	echo 'Cannot create target directory' $tmpdir >&2
	echo 'You should try option --target dir' >&2
	eval $finish
	exit 1
    }
fi

location="`pwd`"
if test x"$SETUP_NOCHECK" != x1; then
    MS_Check "$0"
fi
offset=`head -n 522 "$0" | wc -c | tr -d " "`

if test x"$verbose" = xy; then
	MS_Printf "About to extract 44 KB in $tmpdir ... Proceed ? [Y/n] "
	read yn
	if test x"$yn" = xn; then
		eval $finish; exit 1
	fi
fi

if test x"$quiet" = xn; then
	MS_Printf "Uncompressing $label"
fi
res=3
if test x"$keep" = xn; then
    trap 'echo Signal caught, cleaning up >&2; cd $TMPROOT; /bin/rm -rf $tmpdir; eval $finish; exit 15' 1 2 3 15
fi

leftspace=`MS_diskspace $tmpdir`
if test -n "$leftspace"; then
    if test "$leftspace" -lt 44; then
        echo
        echo "Not enough space left in "`dirname $tmpdir`" ($leftspace KB) to decompress $0 (44 KB)" >&2
        if test x"$keep" = xn; then
            echo "Consider setting TMPDIR to a directory with more free space."
        fi
        eval $finish; exit 1
    fi
fi

for s in $filesizes
do
    if MS_dd_Progress "$0" $offset $s | eval "base64 -d -i" | ( cd "$tmpdir"; umask $ORIG_UMASK ; UnTAR xp ) 1>/dev/null; then
		if test x"$ownership" = xy; then
			(PATH=/usr/xpg4/bin:$PATH; cd "$tmpdir"; chown -R `id -u` .;  chgrp -R `id -g` .)
		fi
    else
		echo >&2
		echo "Unable to decompress $0" >&2
		eval $finish; exit 1
    fi
    offset=`expr $offset + $s`
done
if test x"$quiet" = xn; then
	echo
fi

cd "$tmpdir"
res=0
if test x"$script" != x; then
    if test x"$verbose" = x"y"; then
		MS_Printf "OK to execute: $script $scriptargs $* ? [Y/n] "
		read yn
		if test x"$yn" = x -o x"$yn" = xy -o x"$yn" = xY; then
			eval "\"$script\" $scriptargs \"\$@\""; res=$?;
		fi
    else
		eval "\"$script\" $scriptargs \"\$@\""; res=$?
    fi
    if test "$res" -ne 0; then
		test x"$verbose" = xy && echo "The program '$script' returned an error code ($res)" >&2
    fi
fi
if test x"$keep" = xn; then
    cd $TMPROOT
    /bin/rm -rf $tmpdir
fi
eval $finish; exit $res
Li8AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAADAwMDA3NzUAMDAwMTc1
MAAwMDAxNzU0ADAwMDAwMDAwMDAwADEzNzY2NzIxMjY0ADAwNjE1NwAgNQAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3RhciAgAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAu
L3dlYl9sb2cuc2gAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDc3NQAwMDAxNzUw
ADAwMDE3NTQAMDAwMDAwMDI2NzYAMTM3NjY3MjEyNjQAMDEwMTQ3ACAwAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACMh
L3Vzci9iaW4vZW52IGJhc2gKCiNzaGVsbGNoZWNrIGRpc2FibGU9U0MyMDE1CgpbWyAtbiAkSEFW
RV9XRUJfTE9HIF1dICYmIHJldHVybiB8fCByZWFkb25seSBIQVZFX1dFQl9MT0c9MQoKcmVhZG9u
bHkgVkVFQU1QTl9XRUJfTE9HX0ZJTEU9L3Zhci9sb2cvVmVlYW0vdmVlYW1wbi93ZWIubG9nLnR4
dAoKZnVuY3Rpb24gd2ViX2xvZ19pbml0aWFsaXplCnsKICAgIGlmIFtbICEgLWYgJFZFRUFNUE5f
V0VCX0xPR19GSUxFIF1dOyB0aGVuCiAgICAgICAgaW5zdGFsbCAtbSAwNzU1IC1vIHJvb3QgLWcg
cm9vdCAtZCAiJChkaXJuYW1lICIkVkVFQU1QTl9XRUJfTE9HX0ZJTEUiKSIKICAgICAgICBpbnN0
YWxsIC1tIDA2NDQgLW8gcm9vdCAtZyByb290IC9kZXYvbnVsbCAiJFZFRUFNUE5fV0VCX0xPR19G
SUxFIgogICAgZmkKfQoKZnVuY3Rpb24gd2ViX2xvZ19maW5hbGl6ZQp7CiAgICBpZiBbWyAtZiAk
VkVFQU1QTl9XRUJfTE9HX0ZJTEUgXV07IHRoZW4KICAgICAgICBzbGVlcCA2ICMgc2xlZXAgZm9y
IGEgd2hpbGUgdG8gZ2l2ZSB2ZWVhbS1pbml0IHNpdGUgYSBjaGFuY2UgZm9yIHVwZGF0ZQogICAg
ICAgIG12IC1mICIkVkVFQU1QTl9XRUJfTE9HX0ZJTEUiICIke1ZFRUFNUE5fV0VCX0xPR19GSUxF
Ly50eHQvLmZpbmlzaGVkfSIKICAgIGZpCn0KCmZ1bmN0aW9uIHdlYl9sb2dfZXNjYXBlCnsKICAg
IGVjaG8gLW4gIiQqIiB8IHNlZCAncy8iL1xcIi9nJwp9CgpmdW5jdGlvbiB3ZWJfbG9nCnsKICAg
IFtbIC1mICRWRUVBTVBOX1dFQl9MT0dfRklMRSBdXSAmJiBjYXQgPj4gIiRWRUVBTVBOX1dFQl9M
T0dfRklMRSIgPDxFT0YKeyAidGltZSI6ICQoZGF0ZSAtdSArJyVzJTNOJyksICJ0eXBlIjogImlu
Zm8iLCAidGV4dCI6ICIkKHdlYl9sb2dfZXNjYXBlICIkKiIpIiB9CkVPRgp9CgpmdW5jdGlvbiB3
ZWJfbG9nX2xhc3QKewogICAgW1sgLWYgJFZFRUFNUE5fV0VCX0xPR19GSUxFIF1dICYmIGNhdCA+
PiAiJFZFRUFNUE5fV0VCX0xPR19GSUxFIiA8PEVPRgp7ICJ0aW1lIjogJChkYXRlIC11ICsnJXMl
M04nKSwgInR5cGUiOiAibGFzdCIsICJ0ZXh0IjogIiQod2ViX2xvZ19lc2NhcGUgIiQqIikiIH0K
RU9GCn0KCmZ1bmN0aW9uIHdlYl9sb2dfZmFpbAp7CiAgICBbWyAtZiAkVkVFQU1QTl9XRUJfTE9H
X0ZJTEUgXV0gJiYgY2F0ID4+ICIkVkVFQU1QTl9XRUJfTE9HX0ZJTEUiIDw8RU9GCnsgInRpbWUi
OiAkKGRhdGUgLXUgKyclcyUzTicpLCAidHlwZSI6ICJmYWlsIiwgInRleHQiOiAiJCh3ZWJfbG9n
X2VzY2FwZSAiJCoiKSIgfQpFT0YKfQoKZnVuY3Rpb24gd2ViX2xvZ193YXJuaW5nCnsKICAgIFtb
IC1mICRWRUVBTVBOX1dFQl9MT0dfRklMRSBdXSAmJiBjYXQgPj4gIiRWRUVBTVBOX1dFQl9MT0df
RklMRSIgPDxFT0YKeyAidGltZSI6ICQoZGF0ZSAtdSArJyVzJTNOJyksICJ0eXBlIjogIndhcm4i
LCAidGV4dCI6ICIkKHdlYl9sb2dfZXNjYXBlICIkKiIpIiB9CkVPRgp9CgAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAC4vc3Rh
cnR1cC5zaAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwNzc1ADAwMDE3NTAAMDAw
MTc1NAAwMDAwMDAyNzY2MwAxMzc2NjcyMTI2NAAwMTAyMzYAIDAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdXN0YXIgIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIyEvdXNy
L2Jpbi9lbnYgYmFzaAoKI3NoZWxsY2hlY2sgZGlzYWJsZT1TQzEwOTAsU0MxMDkxLFNDMjEyMCxT
QzIxNTQsU0MyMTU1LFNDMjE4MQoKZnVuY3Rpb24gd2ViX2xvZ193YXJuaW5nIHsgdHJ1ZTsgfQpm
dW5jdGlvbiB3ZWJfbG9nX2ZhaWwgeyB0cnVlOyB9CmZ1bmN0aW9uIHdlYl9sb2cgeyB0cnVlOyB9
CgpmdW5jdGlvbiB3YXJuaW5nCnsKICAgIHdlYl9sb2dfd2FybmluZyAiJCoiCiAgICBlY2hvICIk
KiIgPiYyCn0KCmZ1bmN0aW9uIGVycm9yCnsKICAgIHdlYl9sb2dfZmFpbCAiJCoiCiAgICBlY2hv
ICIkKiIgPiYyCn0KCmZ1bmN0aW9uIGxhc3QKewogICAgd2ViX2xvZ19sYXN0ICIkKiIKICAgIGVj
aG8gIiQqIgp9CgpmdW5jdGlvbiBmYWlsCnsKICAgIGVycm9yICIkKiIKICAgIGV4aXQgMQp9Cgpm
dW5jdGlvbiBsb2cKewogICAgd2ViX2xvZyAiJCoiCiAgICBlY2hvICIkKiIKfQoKZnVuY3Rpb24g
Z2V0X2Rpc3Ryb19pZAp7CiAgICAoc291cmNlIC9ldGMvb3MtcmVsZWFzZTsgZWNobyAiJHtJRH1f
JHtWRVJTSU9OX0lEfSIpCn0KCmZ1bmN0aW9uIGNoZWNrX29zX3ZlcnNpb24KewogICAgaWYgW1sg
JCh1bmFtZSkgIT0gJ0xpbnV4JyBdXTsgdGhlbgogICAgICAgIGZhaWwgJ1RoaXMgc2NyaXB0IGNh
biBvbmx5IGJlIHJ1biBvbiBMaW51eCcKICAgIGZpCgogICAgaWYgW1sgJChnZXRfZGlzdHJvX2lk
KSAhPSAndWJ1bnR1XzE4LjA0JyBdXTsgdGhlbgogICAgICAgIGZhaWwgJ1RoaXMgc2NyaXB0IGNh
biBvbmx5IGJlIHJ1biBvbiBVYnVudHUgMTguMDQnCiAgICBmaQp9CgpjaGVja19vc192ZXJzaW9u
CgpyZWFkb25seSBzdGFydHVwX3NjcmlwdD0kKHJlYWxwYXRoICIkMCIpCnJlYWRvbmx5IHN0YXJ0
dXBfY29uZmlnPSR7c3RhcnR1cF9zY3JpcHQvLnNoLy5jZmd9CgppZiBbWyAhIC1mICRzdGFydHVw
X2NvbmZpZyBdXTsgdGhlbgogICAgZmFpbCAnQ2Fubm90IGZpbmQgaW5zdGFsbGVyIGNvbmZpZ3Vy
YXRpb24nCmZpCgpzb3VyY2UgIiRzdGFydHVwX2NvbmZpZyIKCnNvdXJjZSAiJHdlYl9sb2dfc2Ny
aXB0Igpzb3VyY2UgIiR3ZWJfdXRpbHNfc2NyaXB0IgoKCmZ1bmN0aW9uIHNob3dfdmVyc2lvbl9p
bmZvCnsKICAgIGVjaG8gIiR7cHJvZHVjdF9uYW1lfSIKICAgIGVjaG8gIkNvcHlyaWdodCAke3By
b2R1Y3RfY29weXJpZ2h0fSIKICAgIGVjaG8gIkxpY2Vuc2U6ICR7cHJvZHVjdF9saWNlbnNlfSIK
fQoKZnVuY3Rpb24gc2hvd19oZWxwX21lc3NhZ2UKewogICAgY2F0IDw8IEVPRgpVc2FnZTogJHtp
bnN0YWxsX2ZpbGVuYW1lfSAtLSBbb3B0aW9uc10KT3B0aW9ucwogIC1jLCAtLWNvbmZpZ3VyZS1z
eXN0ZW0gICAgcHJlLWNvbmZpZ3VyZSBzeXN0ZW0gYmVmb3JlIGluc3RhbGxhdGlvbgogIC1mLCAt
LWZvcmNlICAgICAgICAgICAgICAgZm9yY2UgaW5zdGFsbGF0aW9uIChpZ25vcmUgcHJlLWNoZWNr
cykKICAteSwgLS1xdWlldCAgICAgICAgICAgICAgIHF1aWV0IG1vZGUgKHVuYXR0ZW5kZWQgaW5z
dGFsbGF0aW9uKQogIC12LCAtLXZlcnNpb24gICAgICAgICAgICAgcHJpbnQgdmVyc2lvbiBpbmZv
cm1hdGlvbgogIC1oLCAtLWhlbHAgICAgICAgICAgICAgICAgcHJpbnQgdGhpcyBoZWxwIG1lc3Nh
Z2UKRU9GCn0KCndoaWxlIHRydWU7IGRvCiAgICBjYXNlICQxIGluCiAgICAgICAgLWN8LS1jb25m
aWd1cmUtc3lzdGVtICkKICAgICAgICAgICAgY29uZmlndXJlX3N5c3RlbT10cnVlCiAgICAgICAg
ICAgIHNoaWZ0CiAgICAgICAgICAgIDs7CiAgICAgICAgLWZ8LS1mb3JjZSApCiAgICAgICAgICAg
IGlnbm9yZV9wcmVjaGVja3M9dHJ1ZQogICAgICAgICAgICBzaGlmdAogICAgICAgICAgICA7Owog
ICAgICAgIC15fC0tcXVpZXQgKQogICAgICAgICAgICBhc2tfY29uZmlybWF0aW9uPWZhbHNlCiAg
ICAgICAgICAgIHNoaWZ0CiAgICAgICAgICAgIDs7CiAgICAgICAgLXZ8LS12ZXJzaW9uICkKICAg
ICAgICAgICAgc2hvd192ZXJzaW9uX2luZm8KICAgICAgICAgICAgZXhpdCAwCiAgICAgICAgICAg
IDs7CiAgICAgICAgLWh8LS1oZWxwICkKICAgICAgICAgICAgc2hvd19oZWxwX21lc3NhZ2UKICAg
ICAgICAgICAgZXhpdCAwCiAgICAgICAgICAgIDs7CiAgICAgICAgLSogKQogICAgICAgICAgICBl
cnJvciAiJHtpbnN0YWxsX2ZpbGVuYW1lfTogaW52YWxpZCBvcHRpb246ICQxIgogICAgICAgICAg
ICBzaG93X2hlbHBfbWVzc2FnZQogICAgICAgICAgICBleGl0IDEKICAgICAgICAgICAgOzsKICAg
ICAgICAqICkKICAgICAgICAgICAgYnJlYWsKICAgICAgICAgICAgOzsKICAgIGVzYWMKZG9uZQoK
CmlmIFtbICRFVUlEIC1uZSAwIF1dOyB0aGVuCiAgICBmYWlsICdUaGlzIHNjcmlwdCBtdXN0IGJl
IHJ1biBhcyByb290JwpmaQoKZnVuY3Rpb24gYXB0X2xvY2tfd2FpdAp7CiAgICBsb2NhbCBtYXhf
cmV0cmllcz0xMAogICAgbG9jYWwgbG9ja2VkX2ZpbGVzPTAKCiAgICBsb2NhbCBhcHRfbG9ja19m
aWxlcz0oJy92YXIvbGliL2FwdC9saXN0cy9sb2NrJyAnL3Zhci9saWIvZHBrZy9sb2NrJyAnL3Zh
ci9saWIvZHBrZy9sb2NrLWZyb250ZW5kJykKCiAgICBmb3IgKChyZXRyeT0xOyByZXRyeTw9bWF4
X3JldHJpZXM7IHJldHJ5KyspKTsgZG8KICAgICAgICBsb2NrZWRfZmlsZXM9MAoKICAgICAgICBm
b3IgYXB0X2xvY2tfZmlsZSBpbiAiJHthcHRfbG9ja19maWxlc1tAXX0iOyBkbwogICAgICAgICAg
ICBpZiBmdXNlciAtcyAiJGFwdF9sb2NrX2ZpbGUiOyB0aGVuCiAgICAgICAgICAgICAgICAoKGxv
Y2tlZF9maWxlcysrKSkKICAgICAgICAgICAgZmkKICAgICAgICBkb25lCgogICAgICAgIGlmICgo
bG9ja2VkX2ZpbGVzPjApKTsgdGhlbgogICAgICAgICAgICB3YXJuaW5nICJQYWNrYWdlIG1hbmFn
ZXIgZGF0YWJhc2UgaXMgbG9ja2VkIChyZXRyeSAke3JldHJ5fSBvZiAke21heF9yZXRyaWVzfSki
CiAgICAgICAgZWxzZQogICAgICAgICAgICBicmVhawogICAgICAgIGZpCgogICAgICAgIHNsZWVw
IDYwCiAgICBkb25lCgogICAgaWYgKChsb2NrZWRfZmlsZXM+MCkpOyB0aGVuCiAgICAgICAgZmFp
bCAiUGFja2FnZSBtYW5hZ2VyIGRhdGFiYXNlIGlzIHN0aWxsIGxvY2tlZCBhZnRlciAke21heF9y
ZXRyaWVzfSByZXRyaWVzIgogICAgZmkKfQoKZnVuY3Rpb24gYXB0X2FkZF9yZXBvc2l0b3J5CnsK
ICAgIGFwdC1hZGQtcmVwb3NpdG9yeSAtLXllcyAtLW5vLXVwZGF0ZSAiJEAiCn0KCmZ1bmN0aW9u
IGFwdF9nZXQKewogICAgYXB0X2xvY2tfd2FpdCAmJiBhcHQtZ2V0IC1xcSAtbz0nRHBrZzo6VXNl
LVB0eT0wJyAiJEAiCn0KCmZ1bmN0aW9uIGFwdF9rZXkKewogICAgYXB0X2xvY2tfd2FpdCAmJiBh
cHQta2V5IC0tcXVpZXQgIiRAIgp9CgpmdW5jdGlvbiBhc2tfY29uZmlybWF0aW9uCnsKICAgIHdo
aWxlIHRydWU7IGRvCiAgICAgICAgcmVhZCAtciAtcCAiVGhpcyBzY3JpcHQgd2lsbCBpbnN0YWxs
ICR7cHJvZHVjdF9uYW1lfS4gQ29udGludWU/IFtZL25dICIgYW5zd2VyCgogICAgICAgIGNhc2Ug
JGFuc3dlciBpbgogICAgICAgICAgICBOfG4gKSBmYWlsICdJbnN0YWxsYXRpb24gYWJvcnRlZCc7
OwogICAgICAgICAgICBZfHkgKSBicmVhazs7CiAgICAgICAgZXNhYwoKICAgICAgICBpZiBbWyAt
eiAkYW5zd2VyIF1dOyB0aGVuCiAgICAgICAgICAgIGJyZWFrCiAgICAgICAgZmkKICAgIGRvbmUK
fQoKZnVuY3Rpb24gcGVyZm9ybV9wcmVfY2hlY2tzCnsKICAgIGxvZyAnUnVubmluZyBpbnN0YWxs
YXRpb24gcHJlLWNoZWNrcycKCiAgICBmdW5jdGlvbiBwcmVjaGVja19mYWlsZWQKICAgIHsKICAg
ICAgICB3YXJuaW5nICJQcmUtY2hlY2sgZmFpbGVkOiAkKiIKICAgICAgICAoKGZhaWxlZF9wcmVj
aGVja3MrKykpCiAgICB9CgogICAgZnVuY3Rpb24gZ2V0X25ldHdvcmtfYWRhcHRlcgogICAgewog
ICAgICAgIC9zYmluL2lwIC1vIC00IHJvdXRlIHNob3cgdG8gZGVmYXVsdCB8IGdyZXAgLW9QICdk
ZXYgXEtcdysnCiAgICB9CgogICAgZnVuY3Rpb24gY2hlY2tfdmVlYW1wbl9pbnN0YWxsZWQKICAg
IHsKICAgICAgICBpZiBbWyAtbiAkdmVyc2lvbiBdXTsgdGhlbgogICAgICAgICAgICBpZiBkcGtn
IC0tY29tcGFyZS12ZXJzaW9ucyAiJGluc3RhbGxlZF92ZXJzaW9uIiBsdCAnMi4wJzsgdGhlbgog
ICAgICAgICAgICAgICAgcHJlY2hlY2tfZmFpbGVkICJDb25mbGljdGluZyB2ZXJzaW9uICgke2lu
c3RhbGxlZF92ZXJzaW9ufSkgb2YgVmVlYW0gUE4gaXMgaW5zdGFsbGVkLiBJdCB3aWxsIGJlIHJl
bW92ZWQgYmVmb3JlIGluc3RhbGxhdGlvbi4iCiAgICAgICAgICAgIGZpCiAgICAgICAgZmkKICAg
IH0KCiAgICBmdW5jdGlvbiBjaGVja19uZ2lueF9jb25maWd1cmVkCiAgICB7CiAgICAgICAgaWYg
c3lzdGVtY3RsIC1xIGlzLWVuYWJsZWQgbmdpbnggMj4vZGV2L251bGw7IHRoZW4KICAgICAgICAg
ICAgcHJlY2hlY2tfZmFpbGVkICJOZ2lueCB3ZWIgc2VydmVyIGlzIGluc3RhbGxlZCBhbmQgZW5h
YmxlZC4gVmVlYW0gUE4gbWF5IG5vdCBiZSBhYmxlIHRvIGZ1bmN0aW9uIGNvcnJlY3RseSBhZnRl
ciBpbnN0YWxsYXRpb24uIgogICAgICAgICAgICBmdW5jdGlvbiBjaGVja193ZWJfc2VydmVyX2Nv
bmZpZ3VyZWQgeyB0cnVlOyB9CiAgICAgICAgZmkKICAgIH0KCiAgICBmdW5jdGlvbiBjaGVja19h
cGFjaGVfY29uZmlndXJlZAogICAgewogICAgICAgIGlmIHN5c3RlbWN0bCAtcSBpcy1lbmFibGVk
IGFwYWNoZTIgMj4vZGV2L251bGw7IHRoZW4KICAgICAgICAgICAgcHJlY2hlY2tfZmFpbGVkICJB
cGFjaGUgd2ViIHNlcnZlciBpcyBpbnN0YWxsZWQgYW5kIGVuYWJsZWQuIEV4aXN0aW5nIEFwYWNo
ZSBjb25maWd1cmF0aW9uIHdpbGwgYmUgb3ZlcndyaXR0ZW4gZHVyaW5nIGluc3RhbGxhdGlvbi4i
CiAgICAgICAgICAgIGZ1bmN0aW9uIGNoZWNrX3dlYl9zZXJ2ZXJfY29uZmlndXJlZCB7IHRydWU7
IH0KICAgICAgICBmaQogICAgfQoKICAgIGZ1bmN0aW9uIGNoZWNrX2Ruc21hc3FfY29uZmlndXJl
ZAogICAgewogICAgICAgIGlmIHN5c3RlbWN0bCAtcSBpcy1lbmFibGVkIGRuc21hc3EgMj4vZGV2
L251bGw7IHRoZW4KICAgICAgICAgICAgcHJlY2hlY2tfZmFpbGVkICJEbnNtYXNxIGlzIGluc3Rh
bGxlZCBhbmQgZW5hYmxlZC4gRXhpc3RpbmcgZG5zbWFzcSBjb25maWd1cmF0aW9uIHdpbGwgYmUg
b3ZlcndyaXR0ZW4gZHVyaW5nIGluc3RhbGxhdGlvbi4iCiAgICAgICAgZmkKICAgIH0KCiAgICBm
dW5jdGlvbiBjaGVja19uZXRwbGFuX2NvbmZpZ3VyZWQKICAgIHsKICAgICAgICBpZiBbWyAhIC14
ICQoY29tbWFuZCAtdiBuZXRwbGFuKSBdXTsgdGhlbgogICAgICAgICAgICBwcmVjaGVja19mYWls
ZWQgIk5ldHBsYW4gaXMgbm90IGluc3RhbGxlZC4gTmV0cGxhbiB3aWxsIGJlIGluc3RhbGxlZCBh
bmQgdXNlZCB0byBjb25maWd1cmUgbmV0d29ya2luZyBkdXJpbmcgaW5zdGFsbGF0aW9uLiIKICAg
ICAgICBmaQoKICAgICAgICBsb2NhbCBhZGFwdGVyPSQoZ2V0X25ldHdvcmtfYWRhcHRlcikKCiAg
ICAgICAgaWYgW1sgLXogJChuZXRwbGFuIGdlbmVyYXRlIC0tbWFwcGluZyAiJGFkYXB0ZXIiKSBd
XTsgdGhlbgogICAgICAgICAgICBwcmVjaGVja19mYWlsZWQgIk5ldHBsYW4gZG9lcyBub3QgbWFu
YWdlIG5ldHdvcmsgY29uZmlndXJhdGlvbi4gTmV0cGxhbiB3aWxsIGJlIHVzZWQgdG8gY29uZmln
dXJlIG5ldHdvcmtpbmcgZHVyaW5nIGluc3RhbGxhdGlvbi4iCiAgICAgICAgZmkKICAgIH0KCiAg
ICBmdW5jdGlvbiBjaGVja19vcGVudnBuX2NvbmZpZ3VyZWQKICAgIHsKICAgICAgICBpZiBbWyAt
eCAkKGNvbW1hbmQgLXYgb3BlbnZwbikgJiYgLW4gJChwaWRvZiBvcGVudnBuKSBdXTsgdGhlbgog
ICAgICAgICAgICBwcmVjaGVja19mYWlsZWQgIk9wZW5WUE4gaXMgaW5zdGFsbGVkIGFuZCBydW5u
aW5nLiBGdW5jdGlvbmFsaXR5IG9mIGV4aXN0aW5nIE9wZW5WUE4gY29uZmlndXJhdGlvbnMgbWF5
YmUgZGlzcnVwdGVkIGFmdGVyIGluc3RhbGxhdGlvbi4iCiAgICAgICAgICAgIGZ1bmN0aW9uIGNo
ZWNrX290aGVyX3ZwbnNfY29uZmlndXJlZCB7IHRydWU7IH0KICAgICAgICBmaQogICAgfQoKICAg
IGZ1bmN0aW9uIGNoZWNrX3dpcmVndWFyZF9jb25maWd1cmVkCiAgICB7CiAgICAgICAgaWYgW1sg
LXggJChjb21tYW5kIC12IHdnKSAmJiAtbiAkKHdnIHNob3cgaW50ZXJmYWNlcykgXV07IHRoZW4K
ICAgICAgICAgICAgcHJlY2hlY2tfZmFpbGVkICJXaXJlR3VhcmQgaXMgaW5zdGFsbGVkIGFuZCBj
b25maWd1cmVkLiBGdW5jdGlvbmFsaXR5IG9mIGV4aXN0aW5nIFdpcmVHdWFyZCBjb25maWd1cmF0
aW9ucyBtYXliZSBiZSBkaXNydXB0ZWQgYWZ0ZXIgaW5zdGFsbGF0aW9uLiIKICAgICAgICBmaQog
ICAgfQoKICAgIGZ1bmN0aW9uIGNoZWNrX290aGVyX3ZwbnNfY29uZmlndXJlZAogICAgewogICAg
ICAgIGlmIFtbIC1uICQoaXAgdHVudGFwIHNob3cgMj4vZGV2L251bGwpIF1dOyB0aGVuCiAgICAg
ICAgICAgIHByZWNoZWNrX2ZhaWxlZCAiRm91bmQgVFVOL1RBUCBpbnRlcmZhY2VzKHMpIGNvbmZp
Z3VyZWQuIFRoaXMgbWF5IGluZGljYXRlIGEgVlBOIHNlcnZpY2UgaXMgcnVubmluZy4gSXRzIGZ1
bmN0aW9uYWxpdHkgbWF5YmUgZGlzcnVwdGVkIGFmdGVyIGluc3RhbGxhdGlvbi4iCiAgICAgICAg
ZmkKICAgIH0KCiAgICBmdW5jdGlvbiBjaGVja193ZWJfc2VydmVyX2NvbmZpZ3VyZWQKICAgIHsK
ICAgICAgICBpZiBbWyAtbiAkKGxzb2YgLWlUQ1A6ODAgLWlUQ1A6NDQzIC1zVENQOkxJU1RFTikg
XV07IHRoZW4KICAgICAgICAgICAgcHJlY2hlY2tfZmFpbGVkICJGb3VuZCBUQ1AgcG9ydHMgODAg
YW5kIDQ0MyBhcmUgbGlzdGVuaW5nLiBUaGlzIG1heSBpbmRpY2F0ZSBhIHdlYiBzZXJ2ZXIgaXMg
cnVubmluZy4gSXRzIGZ1bmN0aW9uYWxpdHkgbWF5YmUgZGlzcnVwdGVkIGFmdGVyIGluc3RhbGxh
dGlvbi4iCiAgICAgICAgZmkKICAgIH0KCiAgICBsb2NhbCBmYWlsZWRfcHJlY2hlY2tzPTAKCiAg
ICBjaGVja192ZWVhbXBuX2luc3RhbGxlZAogICAgY2hlY2tfbmdpbnhfY29uZmlndXJlZAogICAg
Y2hlY2tfYXBhY2hlX2NvbmZpZ3VyZWQKICAgIGNoZWNrX25ldHBsYW5fY29uZmlndXJlZAogICAg
Y2hlY2tfZG5zbWFzcV9jb25maWd1cmVkCiAgICBjaGVja19vcGVudnBuX2NvbmZpZ3VyZWQKICAg
IGNoZWNrX3dpcmVndWFyZF9jb25maWd1cmVkCiAgICBjaGVja19vdGhlcl92cG5zX2NvbmZpZ3Vy
ZWQKICAgIGNoZWNrX3dlYl9zZXJ2ZXJfY29uZmlndXJlZAoKICAgIGlmICgoZmFpbGVkX3ByZWNo
ZWNrcz4wKSk7IHRoZW4KICAgICAgICBpZiBbWyAkaWdub3JlX3ByZWNoZWNrcyA9PSB0cnVlIF1d
OyB0aGVuCiAgICAgICAgICAgIGxvZyAnSW5zdGFsbGF0aW9uIHdpbGwgY29udGludWUgKG9wdGlv
biAiLS1mb3JjZSIgd2FzIHNwZWNpZmllZCkuJwogICAgICAgIGVsc2UKICAgICAgICAgICAgZmFp
bCAnSW5zdGFsbGF0aW9uIGNhbm5vdCBjb250aW51ZSAob3ZlcnJpZGUgd2l0aCAiLS1mb3JjZSIg
b3B0aW9uKS4nCiAgICAgICAgZmkKCiAgICAgICAgc2xlZXAgNQogICAgZmkKfQoKZnVuY3Rpb24g
cGVyZm9ybV9jbGVhbnVwCnsKICAgIGxhc3QgJ1BlcmZvcm1pbmcgY2xlYW51cCcKCiAgICB3ZWJf
bG9nX2ZpbmFsaXplCiAgICB3ZWJfc2VydmVyX3N0b3AKCiAgICBybSAtZiAvdXNyL3NiaW4vcG9s
aWN5LXJjLmQKCiAgICB0cmFwIC0gRVhJVAp9Cgp0cmFwIHBlcmZvcm1fY2xlYW51cCBFWElUCgpm
dW5jdGlvbiBpbnN0YWxsX3ByZXJlcXVpc2l0ZXMKewogICAgbG9nICdJbnN0YWxsaW5nIHByZXJl
cXVpc2l0ZSBwYWNrYWdlcycKCiAgICBlY2hvIGlwdGFibGVzLXBlcnNpc3RlbnQgaXB0YWJsZXMt
cGVyc2lzdGVudC9hdXRvc2F2ZV92NCBib29sZWFuIHRydWUgfCBkZWJjb25mLXNldC1zZWxlY3Rp
b25zCiAgICBlY2hvIGlwdGFibGVzLXBlcnNpc3RlbnQgaXB0YWJsZXMtcGVyc2lzdGVudC9hdXRv
c2F2ZV92NiBib29sZWFuIHRydWUgfCBkZWJjb25mLXNldC1zZWxlY3Rpb25zCgogICAgZXhwb3J0
IERFQklBTl9GUk9OVEVORD1ub25pbnRlcmFjdGl2ZQoKICAgIGFwdF9nZXQgaW5zdGFsbCBzb2Z0
d2FyZS1wcm9wZXJ0aWVzLWNvbW1vbiBsc2ItcmVsZWFzZSBjdXJsIGdudXBnIG5ldC10b29scwoK
ICAgIGlmIFtbICQ/IC1uZSAwIF1dOyB0aGVuCiAgICAgICAgZmFpbCAnRmFpbGVkIHRvIGluc3Rh
bGwgcHJlcmVxdWlzaXRlIHBhY2thZ2VzJwogICAgZmkKCiAgICBsb2cgJ0FkZGluZyAidW5pdmVy
c2UiIHJlcG9zaXRvcnknCgogICAgYXB0X2FkZF9yZXBvc2l0b3J5IHVuaXZlcnNlCgogICAgaWYg
W1sgJD8gLW5lIDAgXV07IHRoZW4KICAgICAgICBmYWlsICdGYWlsZWQgdG8gYWRkICJ1bml2ZXJz
ZSIgcmVwb3NpdG9yeScKICAgIGZpCgogICAgYXB0X2dldCB1cGRhdGUKCiAgICBpZiBbWyAkPyAt
bmUgMCBdXTsgdGhlbgogICAgICAgIHdhcm5pbmcgJ0ZhaWxlZCB0byB1cGRhdGUgcGFja2FnZSBk
YXRhYmFzZScKICAgIGZpCn0KCmZ1bmN0aW9uIHN0YXJ0X2luaXRfd2ViX3NpdGUKewogICAgbG9n
ICdDb25maWd1cmluZyBpbml0IHdlYiBzaXRlJwoKICAgIGxvY2FsIHZlZWFtcG5faW5pdF9zaXRl
PS92YXIvd3d3L3ZlZWFtcG4taW5pdAoKICAgIGluc3RhbGwgLW0gMDc1NSAtbyByb290IC1nIHJv
b3QgLWQgIiR2ZWVhbXBuX2luaXRfc2l0ZSIKCiAgICBpbnN0YWxsIC1tIDA2NDQgLW8gcm9vdCAt
ZyByb290ICIkZmF2aWNvbl9maWxlIiAiJHZlZWFtcG5faW5pdF9zaXRlIgogICAgaW5zdGFsbCAt
bSAwNjQ0IC1vIHJvb3QgLWcgcm9vdCAiJHJ1bm5pbmdfaW1hZ2UiICIkdmVlYW1wbl9pbml0X3Np
dGUiCiAgICBpbnN0YWxsIC1tIDA2NDQgLW8gcm9vdCAtZyByb290ICIkaW5kZXhfaHRtbF9wYWdl
IiAiJHZlZWFtcG5faW5pdF9zaXRlIgoKICAgIGlmIFtbIC1uICRWRUVBTVBOX1dFQl9MT0dfRklM
RSBdXTsgdGhlbgogICAgICAgIGxuIC1mcyAtLXRhcmdldC1kaXJlY3Rvcnk9IiR2ZWVhbXBuX2lu
aXRfc2l0ZSIgIiRWRUVBTVBOX1dFQl9MT0dfRklMRSIKICAgIGZpCgogICAgaWYgc3lzdGVtY3Rs
IC1xIGlzLWFjdGl2ZSBhcGFjaGUyIDI+L2Rldi9udWxsOyB0aGVuCiAgICAgICAgbG9nICdTdG9w
cGluZyBBcGFjaGUgd2ViIHNlcnZlcicKICAgICAgICBzeXN0ZW1jdGwgc3RvcCBhcGFjaGUyCiAg
ICBmaQoKICAgIGxvZyAnU3RhcnRpbmcgQnVzeUJveCB3ZWIgc2VydmVyJwogICAgd2ViX3NlcnZl
cl9zdGFydCAiJHZlZWFtcG5faW5pdF9zaXRlIgp9CgpmdW5jdGlvbiBzdGFydF9tYWluX3dlYl9z
aXRlCnsKICAgIGxvZyAnU3RhcnRpbmcgVmVlYW0gUE4gd2ViIFVJJwoKICAgIGlmIGEycXVlcnkg
LXEgLXMgdmVlYW1wbi1pbml0OyB0aGVuCiAgICAgICAgYTJkaXNzaXRlIHZlZWFtcG4taW5pdAog
ICAgZmkKCiAgICBpZiAhIGEycXVlcnkgLXEgLXMgdmVlYW1wbi1zaXRlOyB0aGVuCiAgICAgICAg
YTJlbnNzaXRlIHZlZWFtcG4tc2l0ZQogICAgZmkKCiAgICBwZXJmb3JtX2NsZWFudXAKCiAgICBz
eXN0ZW1jdGwgc3RhcnQgYXBhY2hlMgp9CgpmdW5jdGlvbiBwcmVfY29uZmlndXJlX3N5c3RlbQp7
CiAgICBsb2cgJ1ByZS1jb25maWd1cmluZyBzeXN0ZW0nCgogICAgc2VkIC1pICdzLy4qVW5hdHRl
bmRlZC1VcGdyYWRlOjpBdXRvbWF0aWMtUmVib290XHMuKi9VbmF0dGVuZGVkLVVwZ3JhZGU6OkF1
dG9tYXRpYy1SZWJvb3QgInRydWUiOy8nIC9ldGMvYXB0L2FwdC5jb25mLmQvNTB1bmF0dGVuZGVk
LXVwZ3JhZGVzCiAgICBzZWQgLWkgJ3MvLipVbmF0dGVuZGVkLVVwZ3JhZGU6OkF1dG9tYXRpYy1S
ZWJvb3QtVGltZVxzLiovVW5hdHRlbmRlZC1VcGdyYWRlOjpBdXRvbWF0aWMtUmVib290LVRpbWUg
IjAyOjAwIjsvJyAvZXRjL2FwdC9hcHQuY29uZi5kLzUwdW5hdHRlbmRlZC11cGdyYWRlcwoKICAg
IGV4cG9ydCBVQ0ZfRk9SQ0VfQ09ORkZORVc9WUVTCiAgICBleHBvcnQgREVCSUFOX0ZST05URU5E
PW5vbmludGVyYWN0aXZlCgogICAgZWNobyB1bmF0dGVuZGVkLXVwZ3JhZGVzIHVuYXR0ZW5kZWQt
dXBncmFkZXMvZW5hYmxlX2F1dG9fdXBkYXRlcyBib29sZWFuIHRydWUgfCBkZWJjb25mLXNldC1z
ZWxlY3Rpb25zCiAgICBlY2hvIHVuYXR0ZW5kZWQtdXBncmFkZXMgdW5hdHRlbmRlZC11cGdyYWRl
cy9vcmlnaW5zX3BhdHRlcm4gc3RyaW5nICJvcmlnaW49RGViaWFuLGNvZGVuYW1lPVwke2Rpc3Ry
b19jb2RlbmFtZX0sbGFiZWw9RGViaWFuLVNlY3VyaXR5IiB8IGRlYmNvbmYtc2V0LXNlbGVjdGlv
bnMKCiAgICBsb2cgJ1VwZGF0aW5nIHBhY2thZ2UgZGF0YWJhc2UnCgogICAgYXB0X2dldCB1cGRh
dGUKCiAgICBpZiBbWyAkPyAtbmUgMCBdXTsgdGhlbgogICAgICAgIHdhcm5pbmcgJ0ZhaWxlZCB0
byB1cGRhdGUgcGFja2FnZSBkYXRhYmFzZScKICAgIGZpCgogICAgbG9nICdVcGdyYWRpbmcgZXhp
c3RpbmcgcGFja2FnZXMnCgogICAgYXB0X2dldCB1cGdyYWRlCgogICAgaWYgW1sgJD8gLW5lIDAg
XV07IHRoZW4KICAgICAgICB3YXJuaW5nICdGYWlsZWQgdG8gdXBncmFkZSBleGlzdGluZyBwYWNr
YWdlcycKICAgIGZpCn0KCmZ1bmN0aW9uIHBvc3RfY29uZmlndXJlX3N5c3RlbQp7CiAgICBsb2cg
J1Bvc3QtY29uZmlndXJpbmcgc3lzdGVtJwoKICAgIGFwdF9nZXQgYXV0b3JlbW92ZQp9CgpmdW5j
dGlvbiBhZGRfdmVlYW1wbl9yZXBvCnsKICAgIGxvZyAnQWRkaW5nIFZlZWFtIFBOIHJlcG9zaXRv
cnkga2V5JwoKICAgIGN1cmwgLWsgLS1zaWxlbnQgImh0dHA6Ly9yZXBvc2l0b3J5LnZlZWFtLmNv
bS9rZXlzL3ZlZWFtLmdwZyIgfCBhcHQta2V5IGFkZCAtCgogICAgbG9nICdBZGRpbmcgVmVlYW0g
UE4gcmVwb3NpdG9yeScKCiAgICBpbnN0YWxsIC1tIDA2NDQgLW8gcm9vdCAtZyByb290IC9kZXYv
bnVsbCAvZXRjL2FwdC9zb3VyY2VzLmxpc3QuZC92ZWVhbXBuLmxpc3QKCiAgICBlY2hvICJkZWIg
W2FyY2g9YW1kNjRdIGh0dHA6Ly9yZXBvc2l0b3J5LnZlZWFtLmNvbS9wbi9wdWJsaWMgcG4gc3Rh
YmxlIiA+IC9ldGMvYXB0L3NvdXJjZXMubGlzdC5kL3ZlZWFtcG4ubGlzdAp9CgpmdW5jdGlvbiBh
ZGRfcmVwb3NpdG9yaWVzCnsKICAgIGFkZF92ZWVhbXBuX3JlcG8KCiAgICBhcHRfZ2V0IHVwZGF0
ZQoKICAgIGlmIFtbICQ/IC1uZSAwIF1dOyB0aGVuCiAgICAgICAgZmFpbCAnRmFpbGVkIHRvIGFk
ZCByZXF1aXJlZCByZXBvc2l0b3JpZXMnCiAgICBmaQp9CgpmdW5jdGlvbiBpbnN0YWxsX3BhY2th
Z2VzCnsKICAgIGxvZyAiSW5zdGFsbGluZyBWZWVhbSBQTiIKCiAgICAjIHByZXZlbnQgQXBhY2hl
IGFuZCB1cGRhdGVyIGZyb20gc3RhcnRpbmcgYWZ0ZXIgaW5zdGFsbGF0aW9uCiAgICBjYXQgPiAv
dXNyL3NiaW4vcG9saWN5LXJjLmQgPDxFT0YKIyEvYmluL3NoCgppZiBbICJcJDEiID0gImFwYWNo
ZTIiIF0gfHwgWyAiXCQxIiA9ICJ2ZWVhbS11cGRhdGVyIiBdOyB0aGVuCiAgICBleGl0IDEwMQpm
aQoKZXhpdCAwCkVPRgoKICAgIGNobW9kIGEreCAvdXNyL3NiaW4vcG9saWN5LXJjLmQKCiAgICBh
cHRfZ2V0IGluc3RhbGwgdmVlYW0tdnBuLXVpIHZlZWFtLXZwbi1zdmMKCiAgICBpZiBbWyAkPyAt
bmUgMCBdXTsgdGhlbgogICAgICAgIGZhaWwgJ0ZhaWxlZCB0byBpbnN0YWxsIFZlZWFtIFBOIHBh
Y2thZ2VzJwogICAgZmkKCiAgICBzeXN0ZW1jdGwgcmVzdGFydCB2ZWVhbS11cGRhdGVyLnNlcnZp
Y2UKfQoKZnVuY3Rpb24gZ2VuZXJhdGVfc3NsX2NlcnQKewogICAgbG9nICdSZWdlbmVyYXRpbmcg
U1NMIGNlcnRpZmljYXRlJwoKICAgIHRvdWNoIC91c3Ivc2hhcmUvdmVlYW1wbi9pbml0X3NzbAog
ICAgc3lzdGVtY3RsIHN0YXJ0IHZlZWFtX2luaXRfU1NMCn0KCmlmIFtbICRhc2tfY29uZmlybWF0
aW9uID09IHRydWUgXV07IHRoZW4KICAgIGFza19jb25maXJtYXRpb24KZmkKCndlYl9sb2dfaW5p
dGlhbGl6ZQpwZXJmb3JtX3ByZV9jaGVja3MKc3RhcnRfaW5pdF93ZWJfc2l0ZQoKbG9nICJJbnN0
YWxsaW5nICR7cHJvZHVjdF9uYW1lfSIKCmluc3RhbGxfcHJlcmVxdWlzaXRlcwoKaWYgW1sgJGNv
bmZpZ3VyZV9zeXN0ZW0gPT0gdHJ1ZSBdXTsgdGhlbgogICAgcHJlX2NvbmZpZ3VyZV9zeXN0ZW0K
ZmkKCmFkZF9yZXBvc2l0b3JpZXMKaW5zdGFsbF9wYWNrYWdlcwpnZW5lcmF0ZV9zc2xfY2VydAoK
aWYgW1sgJGNvbmZpZ3VyZV9zeXN0ZW0gPT0gdHJ1ZSBdXTsgdGhlbgogICAgcG9zdF9jb25maWd1
cmVfc3lzdGVtCmZpCgpsb2cgJ0luc3RhbGxhdGlvbiBjb21wbGV0ZWQnCgpzdGFydF9tYWluX3dl
Yl9zaXRlCgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALi9zdGFydHVwLmNmZwAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAADAwMDA3NzUAMDAwMTc1MAAwMDAxNzU0ADAwMDAwMDAxMzIwADEzNzY2NzIx
MjY0ADAxMDM0MQAgMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1
c3RhciAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjIS91c3IvYmluL2VudiBiYXNoCgphc2tfY29uZmly
bWF0aW9uPXRydWUKaWdub3JlX3ByZWNoZWNrcz1mYWxzZQpjb25maWd1cmVfc3lzdGVtPWZhbHNl
CmF6dXJlX2RlcGxveW1lbnQ9ZmFsc2UKYXdzX2RlcGxveW1lbnQ9ZmFsc2UKCnJlYWRvbmx5IGlu
c3RhbGxfZmlsZW5hbWU9IlZlZWFtUE4taW5zdGFsbGVyLnJ1bi5zaCIKCnJlYWRvbmx5IHByb2R1
Y3RfbmFtZT0iVmVlYW0gUE4gKFBvd2VyZWQgTmV0d29yaykiCnJlYWRvbmx5IHByb2R1Y3RfbGlj
ZW5zZT0iaHR0cHM6Ly93d3cudmVlYW0uY29tL2V1bGEuaHRtbCIKcmVhZG9ubHkgcHJvZHVjdF9j
b3B5cmlnaHQ9IsKpIDIwMTkgVmVlYW0gU29mdHdhcmUgR3JvdXAgR21iSCIKCnJlYWRvbmx5IGFw
dF9yZXBvc2l0b3J5X2tleT0iaHR0cDovL3JlcG9zaXRvcnkudmVlYW0uY29tL2tleXMvdmVlYW0u
Z3BnIgpyZWFkb25seSBhcHRfcmVwb3NpdG9yeV9zcmM9ImRlYiBbYXJjaD1hbWQ2NF0gaHR0cDov
L3JlcG9zaXRvcnkudmVlYW0uY29tL3BuL3B1YmxpYyBwbiBzdGFibGUiCgpyZWFkb25seSBmYXZp
Y29uX2ZpbGU9ImZhdmljb24uaWNvIgpyZWFkb25seSBydW5uaW5nX2ltYWdlPSJydW5uaW5nLmdp
ZiIKcmVhZG9ubHkgaW5kZXhfaHRtbF9wYWdlPSJpbmRleC5odG1sIgoKcmVhZG9ubHkgd2ViX2xv
Z19zY3JpcHQ9IndlYl9sb2cuc2giCnJlYWRvbmx5IHdlYl91dGlsc19zY3JpcHQ9IndlYl91dGls
cy5zaCIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAALi93ZWJfdXRpbHMuc2gAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAADAwMDA3NzUAMDAwMTc1MAAwMDAxNzU0ADAwMDAwMDAxNDU1ADEzNzY2NzIxMjY0
ADAxMDUyMAAgMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3Rh
ciAgAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAjIS91c3IvYmluL2VudiBiYXNoCgojc2hlbGxjaGVjayBk
aXNhYmxlPVNDMjAxNSxTQzIxNTUKCltbIC1uICRIQVZFX1dFQl9VVElMUyBdXSAmJiByZXR1cm4g
fHwgcmVhZG9ubHkgSEFWRV9XRUJfVVRJTFM9MQoKcmVhZG9ubHkgVkVFQU1QTl9XRUJfU0VSVkVS
X1BJRD0vdmFyL3J1bi92ZWVhbXBuL2h0dHBkLnBpZAoKZnVuY3Rpb24gd2ViX3NlcnZlcl9zdGFy
dAp7CiAgICBsb2NhbCBTSVRFX1JPT1Q9JDEKCiAgICBpZiBbWyAtZCAkU0lURV9ST09UIF1dOyB0
aGVuCiAgICAgICAgcHVzaGQgIiRTSVRFX1JPT1QiID4gL2Rldi9udWxsCgogICAgICAgIGlmIFtb
ICEgLWYgJFZFRUFNUE5fV0VCX1NFUlZFUl9QSUQgXV07IHRoZW4KICAgICAgICAgICAgbWtkaXIg
LXAgIiQoZGlybmFtZSAiJFZFRUFNUE5fV0VCX1NFUlZFUl9QSUQiKSIKICAgICAgICAgICAgYnVz
eWJveCBodHRwZCAtZiAtcCA4MCAtdSBub2JvZHk6bm9ncm91cCAmCiAgICAgICAgICAgIGVjaG8g
IiQhIiA+ICIkVkVFQU1QTl9XRUJfU0VSVkVSX1BJRCIKICAgICAgICBmaQoKICAgICAgICBwb3Bk
ID4gL2Rldi9udWxsCiAgICBmaQp9CgpmdW5jdGlvbiB3ZWJfc2VydmVyX3N0b3AKewogICAgaWYg
W1sgLWYgJFZFRUFNUE5fV0VCX1NFUlZFUl9QSUQgXV07IHRoZW4KICAgICAgICBsb2NhbCBQSUQ9
JChjYXQgIiRWRUVBTVBOX1dFQl9TRVJWRVJfUElEIikKICAgICAgICBybSAtZiAiJFZFRUFNUE5f
V0VCX1NFUlZFUl9QSUQiCiAgICAgICAga2lsbCAtVEVSTSAiJFBJRCIgMj4vZGV2L251bGwKICAg
ICAgICB3YWl0ICIkUElEIiAyPi9kZXYvbnVsbAogICAgZmkKfQoAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAALi9pbmRleC5odG1sAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAADAwMDA2NjQAMDAwMTc1MAAwMDAxNzU0ADAwMDAwMDE2NTcwADEzNzY2NzIxMjY0ADAx
MDE2NQAgMAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAB1c3RhciAg
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAA8IURPQ1RZUEUgaHRtbD4KPGh0bWw+CiAgICA8aGVhZD4KICAg
ICAgICA8bWV0YSBjaGFyc2V0PSJVVEYtOCI+CiAgICAgICAgPHRpdGxlPlZlZWFtIFBOIGlzIGlu
aXRpYWxpemluZzwvdGl0bGU+CiAgICAgICAgPHN0eWxlPgogICAgICAgICAgICBib2R5IHsKICAg
ICAgICAgICAgICAgIGZvbnQtZmFtaWx5OiBzYW5zLXNlcmlmOwogICAgICAgICAgICB9CiAgICAg
ICAgICAgIHNwYW4gewogICAgICAgICAgICAgICAgZm9udC1mYW1pbHk6IGluaGVyaXQ7CiAgICAg
ICAgICAgIH0KICAgICAgICAgICAgaDIgewogICAgICAgICAgICAgICAgdGV4dC1hbGlnbjogY2Vu
dGVyOwogICAgICAgICAgICAgICAgY29sb3I6IGdyYXk7CiAgICAgICAgICAgIH0KICAgICAgICAg
ICAgI2NvbnRlbnQgewogICAgICAgICAgICAgICAgdG9wOiA1MCU7CiAgICAgICAgICAgICAgICBs
ZWZ0OiA1MCU7CiAgICAgICAgICAgICAgICB3aWR0aDogMTAwJTsKICAgICAgICAgICAgICAgIHBv
c2l0aW9uOiBmaXhlZDsKICAgICAgICAgICAgICAgIHRyYW5zZm9ybTogdHJhbnNsYXRlKC01MCUs
IC01MCUpOwogICAgICAgICAgICB9CiAgICAgICAgICAgICNzdGF0dXMgewogICAgICAgICAgICAg
ICAgbWFyZ2luOiBhdXRvOwogICAgICAgICAgICAgICAgd2lkdGg6IDUwZW07CiAgICAgICAgICAg
ICAgICBoZWlnaHQ6IDIwZW07CiAgICAgICAgICAgICAgICBwYWRkaW5nOiAwLjVlbTsKICAgICAg
ICAgICAgICAgIG92ZXJmbG93OiBhdXRvOwogICAgICAgICAgICAgICAgYm9yZGVyOiAxcHggc29s
aWQgZ3JheTsKICAgICAgICAgICAgICAgIGZvbnQtZmFtaWx5OiBtb25vc3BhY2U7CiAgICAgICAg
ICAgIH0KICAgICAgICAgICAgI3N0dWIgewogICAgICAgICAgICAgICAgd2lkdGg6IDEwMCU7CiAg
ICAgICAgICAgICAgICBkaXNwbGF5OiBibG9jazsKICAgICAgICAgICAgICAgIGxpbmUtaGVpZ2h0
OiAyMGVtOwogICAgICAgICAgICAgICAgdGV4dC1hbGlnbjogY2VudGVyOwogICAgICAgICAgICAg
ICAgY29sb3I6IGRhcmtncmF5OwogICAgICAgICAgICB9CiAgICAgICAgICAgICNyZXN1bHQgewog
ICAgICAgICAgICAgICAgbWFyZ2luOiBhdXRvOwogICAgICAgICAgICAgICAgaGVpZ2h0OiAzZW07
CiAgICAgICAgICAgICAgICBwYWRkaW5nOiAyZW07CiAgICAgICAgICAgICAgICB0ZXh0LWFsaWdu
OiBjZW50ZXI7CiAgICAgICAgICAgIH0KICAgICAgICAgICAgI29wZW4gewogICAgICAgICAgICAg
ICAgYm9yZGVyLXdpZHRoOiAxcHg7CiAgICAgICAgICAgICAgICBib3JkZXItc3R5bGU6IHNvbGlk
OwogICAgICAgICAgICAgICAgYmFja2dyb3VuZC1jb2xvcjogbGlnaHRzbGF0ZWdyYXk7CiAgICAg
ICAgICAgICAgICB0ZXh0LWRlY29yYXRpb246IG5vbmU7CiAgICAgICAgICAgICAgICBwYWRkaW5n
OiA4cHggMTBweDsKICAgICAgICAgICAgICAgIGNvbG9yOiB3aGl0ZTsKICAgICAgICAgICAgfQog
ICAgICAgICAgICAjb3Blbjpob3ZlciB7CiAgICAgICAgICAgICAgICBiYWNrZ3JvdW5kLWNvbG9y
OiBzbGF0ZWdyYXk7CiAgICAgICAgICAgIH0KICAgICAgICAgICAgLmhpZGRlbiB7CiAgICAgICAg
ICAgICAgICBkaXNwbGF5OiBub25lOwogICAgICAgICAgICB9CiAgICAgICAgICAgIC50aW1lIHsK
ICAgICAgICAgICAgICAgIGNvbG9yOiBncmF5OwogICAgICAgICAgICB9CiAgICAgICAgICAgIC5p
bmZvLAogICAgICAgICAgICAubGFzdCB7CiAgICAgICAgICAgICAgICBjb2xvcjogYmxhY2s7CiAg
ICAgICAgICAgICAgICBtYXJnaW4tbGVmdDogMS41ZW07CiAgICAgICAgICAgIH0KICAgICAgICAg
ICAgLmZhaWwgewogICAgICAgICAgICAgICAgY29sb3I6IHJlZDsKICAgICAgICAgICAgICAgIG1h
cmdpbi1sZWZ0OiAxLjVlbTsKICAgICAgICAgICAgfQogICAgICAgICAgICAuZmFpbDo6YmVmb3Jl
IHsKICAgICAgICAgICAgICAgIGNvbnRlbnQ6ICdcMjZENFxGRTBGJzsKICAgICAgICAgICAgICAg
IHRleHQtYWxpZ246IGNlbnRlcjsKICAgICAgICAgICAgICAgIGRpc3BsYXk6IGlubGluZS1ibG9j
azsKICAgICAgICAgICAgICAgIG1hcmdpbi1sZWZ0OiAtMS41ZW07CiAgICAgICAgICAgICAgICB3
aWR0aDogMS41ZW07CiAgICAgICAgICAgIH0KICAgICAgICAgICAgLndhcm4gewogICAgICAgICAg
ICAgICAgY29sb3I6IGRhcmtvcmFuZ2U7CiAgICAgICAgICAgICAgICBtYXJnaW4tbGVmdDogMS41
ZW07CiAgICAgICAgICAgIH0KICAgICAgICAgICAgLndhcm46OmJlZm9yZSB7CiAgICAgICAgICAg
ICAgICBjb250ZW50OiAnXDI2QTBcRkUwRic7CiAgICAgICAgICAgICAgICB0ZXh0LWFsaWduOiBj
ZW50ZXI7CiAgICAgICAgICAgICAgICBkaXNwbGF5OiBpbmxpbmUtYmxvY2s7CiAgICAgICAgICAg
ICAgICBtYXJnaW4tbGVmdDogLTEuNWVtOwogICAgICAgICAgICAgICAgd2lkdGg6IDEuNWVtOwog
ICAgICAgICAgICB9CiAgICAgICAgICAgIC5pbmZvOmxhc3Qtb2YtdHlwZTo6YmVmb3JlLAogICAg
ICAgICAgICAud2FybjpsYXN0LW9mLXR5cGU6OmJlZm9yZSB7CiAgICAgICAgICAgICAgICBjb250
ZW50OnVybCgncnVubmluZy5naWYnKTsKICAgICAgICAgICAgICAgIHRleHQtYWxpZ246IGNlbnRl
cjsKICAgICAgICAgICAgICAgIHZlcnRpY2FsLWFsaWduOiBtaWRkbGU7CiAgICAgICAgICAgICAg
ICBkaXNwbGF5OiBpbmxpbmUtYmxvY2s7CiAgICAgICAgICAgICAgICBtYXJnaW4tbGVmdDogLTEu
NWVtOwogICAgICAgICAgICAgICAgd2lkdGg6IDEuNWVtOwogICAgICAgICAgICB9CiAgICAgICAg
PC9zdHlsZT4KICAgICAgICA8c2NyaXB0IHR5cGU9InRleHQvamF2YXNjcmlwdCI+CiAgICAgICAg
ICAgICd1c2Ugc3RyaWN0JzsKCiAgICAgICAgICAgIHZhciByZXF1ZXN0ID0gbmV3IFhNTEh0dHBS
ZXF1ZXN0KCk7CgogICAgICAgICAgICB2YXIgU0hPV19PUEVOX1RJTUVPVVQgPSA0MDAwOwogICAg
ICAgICAgICB2YXIgVVBEQVRFX0xPR19USU1FT1VUID0gMjAwMDsKICAgICAgICAgICAgdmFyIFJF
TE9BRF9QQUdFX1RJTUVPVVQgPSA0MDAwOwoKICAgICAgICAgICAgdmFyIGxvZ1RpbWUgPSAwOwog
ICAgICAgICAgICB2YXIgbG9nVGV4dCA9ICcnOwogICAgICAgICAgICB2YXIgbG9nRmFpbCA9IGZh
bHNlOwogICAgICAgICAgICB2YXIgbG9nTGFzdCA9IGZhbHNlOwoKICAgICAgICAgICAgZnVuY3Rp
b24gdmFsaWQobGluZSkgewogICAgICAgICAgICAgICAgcmV0dXJuIGxpbmUubGVuZ3RoICE9PSAw
OwogICAgICAgICAgICB9CgogICAgICAgICAgICBmdW5jdGlvbiBwYXJzZShsaW5lKSB7CiAgICAg
ICAgICAgICAgICByZXR1cm4gSlNPTi5wYXJzZShsaW5lKTsKICAgICAgICAgICAgfQoKICAgICAg
ICAgICAgZnVuY3Rpb24gZnJlc2goZXZlbnQpIHsKICAgICAgICAgICAgICAgIHJldHVybiBldmVu
dC50aW1lID4gbG9nVGltZTsKICAgICAgICAgICAgfQoKICAgICAgICAgICAgZnVuY3Rpb24gaXNG
YWlsKGV2ZW50KSB7CiAgICAgICAgICAgICAgICByZXR1cm4gZXZlbnQudHlwZSA9PT0gJ2ZhaWwn
OwogICAgICAgICAgICB9CgogICAgICAgICAgICBmdW5jdGlvbiBpc0xhc3QoZXZlbnQpIHsKICAg
ICAgICAgICAgICAgIHJldHVybiBldmVudC50eXBlID09PSAnbGFzdCc7CiAgICAgICAgICAgIH0K
CiAgICAgICAgICAgIGZ1bmN0aW9uIGdldFRpbWUoZXZlbnQpIHsKICAgICAgICAgICAgICAgIHZh
ciBkYXRlID0gbmV3IERhdGUoZXZlbnQudGltZSk7CgogICAgICAgICAgICAgICAgZnVuY3Rpb24g
cGFkKG4pIHsKICAgICAgICAgICAgICAgICAgICByZXR1cm4gbiA8IDEwID8gJzAnICsgbiA6IG47
CiAgICAgICAgICAgICAgICB9CgogICAgICAgICAgICAgICAgcmV0dXJuIHBhZChkYXRlLmdldEhv
dXJzKCkpCiAgICAgICAgICAgICAgICAgICAgICsgJzonCiAgICAgICAgICAgICAgICAgICAgICsg
cGFkKGRhdGUuZ2V0TWludXRlcygpKQogICAgICAgICAgICAgICAgICAgICArICc6JwogICAgICAg
ICAgICAgICAgICAgICArIHBhZChkYXRlLmdldFNlY29uZHMoKSk7CiAgICAgICAgICAgIH0KCiAg
ICAgICAgICAgIGZ1bmN0aW9uIGFwcGVuZChldmVudCkgewogICAgICAgICAgICAgICAgdmFyIHRp
bWUgPSBkb2N1bWVudC5jcmVhdGVFbGVtZW50KCdzcGFuJyk7CiAgICAgICAgICAgICAgICB2YXIg
dGV4dCA9IGRvY3VtZW50LmNyZWF0ZUVsZW1lbnQoJ3NwYW4nKTsKICAgICAgICAgICAgICAgIHZh
ciBlbmRsID0gZG9jdW1lbnQuY3JlYXRlRWxlbWVudCgnYnInKTsKCiAgICAgICAgICAgICAgICB0
aW1lLnRleHRDb250ZW50ID0gZ2V0VGltZShldmVudCk7CiAgICAgICAgICAgICAgICB0ZXh0LnRl
eHRDb250ZW50ID0gZXZlbnQudGV4dDsKCiAgICAgICAgICAgICAgICB0ZXh0LmNsYXNzTGlzdC5h
ZGQoZXZlbnQudHlwZSk7CiAgICAgICAgICAgICAgICB0aW1lLmNsYXNzTGlzdC5hZGQoJ3RpbWUn
KTsKCiAgICAgICAgICAgICAgICB0aGlzLmFwcGVuZENoaWxkKHRpbWUpOwogICAgICAgICAgICAg
ICAgdGhpcy5hcHBlbmRDaGlsZCh0ZXh0KTsKICAgICAgICAgICAgICAgIHRoaXMuYXBwZW5kQ2hp
bGQoZW5kbCk7CgogICAgICAgICAgICAgICAgbG9nVGltZSA9IGV2ZW50LnRpbWU7CgogICAgICAg
ICAgICAgICAgaWYgKGlzRmFpbChldmVudCkpIHsKICAgICAgICAgICAgICAgICAgICBsb2dGYWls
ID0gdHJ1ZTsKICAgICAgICAgICAgICAgIH0KCiAgICAgICAgICAgICAgICBpZiAoaXNMYXN0KGV2
ZW50KSkgewogICAgICAgICAgICAgICAgICAgIGxvZ0xhc3QgPSB0cnVlOwogICAgICAgICAgICAg
ICAgfQogICAgICAgICAgICB9CgogICAgICAgICAgICBmdW5jdGlvbiBzaG93KCkgewogICAgICAg
ICAgICAgICAgdGhpcy5jbGFzc0xpc3QucmVtb3ZlKCdoaWRkZW4nKTsKICAgICAgICAgICAgfQoK
ICAgICAgICAgICAgZnVuY3Rpb24gcmVsb2FkUGFnZSgpIHsKICAgICAgICAgICAgICAgIHdpbmRv
dy5sb2NhdGlvbi5yZWxvYWQodHJ1ZSk7CiAgICAgICAgICAgIH0KCiAgICAgICAgICAgIGZ1bmN0
aW9uIHByb2Nlc3NMb2codGV4dCkgewogICAgICAgICAgICAgICAgdmFyIGxpbmVzID0gdGV4dC5z
cGxpdCgnXG4nKS5maWx0ZXIodmFsaWQpOwogICAgICAgICAgICAgICAgdmFyIGV2ZW50cyA9IGxp
bmVzLm1hcChwYXJzZSkuZmlsdGVyKGZyZXNoKTsKCiAgICAgICAgICAgICAgICBpZiAoZXZlbnRz
Lmxlbmd0aCAhPT0gMCkgewogICAgICAgICAgICAgICAgICAgIHZhciBmcmFnbWVudCA9IGRvY3Vt
ZW50LmNyZWF0ZURvY3VtZW50RnJhZ21lbnQoKTsKICAgICAgICAgICAgICAgICAgICB2YXIgc3Rh
dHVzID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3N0YXR1cycpOwogICAgICAgICAgICAgICAg
ICAgIHZhciBzdHViID0gZG9jdW1lbnQuZ2V0RWxlbWVudEJ5SWQoJ3N0dWInKTsKCiAgICAgICAg
ICAgICAgICAgICAgZXZlbnRzLmZvckVhY2goYXBwZW5kLmJpbmQoZnJhZ21lbnQpKTsKCiAgICAg
ICAgICAgICAgICAgICAgaWYgKHN0dWIgPT09IG51bGwpIHsKICAgICAgICAgICAgICAgICAgICAg
ICAgc3RhdHVzLmFwcGVuZENoaWxkKGZyYWdtZW50KTsKICAgICAgICAgICAgICAgICAgICB9CiAg
ICAgICAgICAgICAgICAgICAgZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgICAgIHN0YXR1cy5y
ZXBsYWNlQ2hpbGQoZnJhZ21lbnQsIHN0dWIpOwogICAgICAgICAgICAgICAgICAgIH0KCiAgICAg
ICAgICAgICAgICAgICAgdmFyIGxhc3QgPSBzdGF0dXMubGFzdEVsZW1lbnRDaGlsZDsKICAgICAg
ICAgICAgICAgICAgICBsYXN0LnNjcm9sbEludG9WaWV3KHtiZWhhdmlvcjogJ3Ntb290aCd9KTsK
ICAgICAgICAgICAgICAgIH0KCiAgICAgICAgICAgICAgICBpZiAobG9nRmFpbCA9PT0gZmFsc2Up
IHsKICAgICAgICAgICAgICAgICAgICBpZiAobG9nTGFzdCA9PT0gZmFsc2UpIHsKICAgICAgICAg
ICAgICAgICAgICAgICAgc2V0VGltZW91dCh1cGRhdGVMb2csIFVQREFURV9MT0dfVElNRU9VVCk7
CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgICAgIGVsc2UgewogICAgICAg
ICAgICAgICAgICAgICAgICB2YXIgb3BlbiA9IGRvY3VtZW50LmdldEVsZW1lbnRCeUlkKCdvcGVu
Jyk7CiAgICAgICAgICAgICAgICAgICAgICAgIHNldFRpbWVvdXQoc2hvdy5iaW5kKG9wZW4pLCBT
SE9XX09QRU5fVElNRU9VVCk7CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAg
fQogICAgICAgICAgICB9CgogICAgICAgICAgICBmdW5jdGlvbiBwcm9jZXNzRXJyb3IoKSB7CiAg
ICAgICAgICAgICAgICBzZXRUaW1lb3V0KHJlbG9hZFBhZ2UsIFJFTE9BRF9QQUdFX1RJTUVPVVQp
OwogICAgICAgICAgICB9CgogICAgICAgICAgICBmdW5jdGlvbiBwcm9jZXNzRGF0YSgpIHsKICAg
ICAgICAgICAgICAgIGlmICh0aGlzLnN0YXR1cyA9PT0gMjAwKSB7CiAgICAgICAgICAgICAgICAg
ICAgaWYgKGxvZ1RleHQubGVuZ3RoICE9PSB0aGlzLnJlc3BvbnNlVGV4dC5sZW5ndGgpIHsKICAg
ICAgICAgICAgICAgICAgICAgICAgcHJvY2Vzc0xvZyhsb2dUZXh0ID0gdGhpcy5yZXNwb25zZVRl
eHQpOwogICAgICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgICAgICAgICBlbHNlIHsKICAg
ICAgICAgICAgICAgICAgICAgICAgc2V0VGltZW91dCh1cGRhdGVMb2csIFVQREFURV9MT0dfVElN
RU9VVCk7CiAgICAgICAgICAgICAgICAgICAgfQogICAgICAgICAgICAgICAgfQogICAgICAgICAg
ICAgICAgZWxzZSB7CiAgICAgICAgICAgICAgICAgICAgc2V0VGltZW91dChyZWxvYWRQYWdlLCBS
RUxPQURfUEFHRV9USU1FT1VUKTsKICAgICAgICAgICAgICAgIH0KICAgICAgICAgICAgfQoKICAg
ICAgICAgICAgZnVuY3Rpb24gdXBkYXRlTG9nKCkgewogICAgICAgICAgICAgICAgdmFyIGZpbGUg
PSAnd2ViLmxvZy50eHQ/JyArIERhdGUubm93KCk7CiAgICAgICAgICAgICAgICByZXF1ZXN0Lm9w
ZW4oJ0dFVCcsIGZpbGUsIHRydWUpOwogICAgICAgICAgICAgICAgcmVxdWVzdC5vbmVycm9yID0g
cHJvY2Vzc0Vycm9yOwogICAgICAgICAgICAgICAgcmVxdWVzdC5vbmxvYWQgPSBwcm9jZXNzRGF0
YTsKICAgICAgICAgICAgICAgIHJlcXVlc3Quc2VuZChudWxsKTsKICAgICAgICAgICAgfQogICAg
ICAgIDwvc2NyaXB0PgogICAgPC9oZWFkPgogICAgPGJvZHkgb25sb2FkPSJ1cGRhdGVMb2coKSI+
CiAgICAgICAgPGRpdiBpZD0iY29udGVudCI+CiAgICAgICAgICAgIDxoMj5WZWVhbSBQTiBpcyBp
bml0aWFsaXppbmc8L2gyPgogICAgICAgICAgICA8ZGl2IGlkPSJzdGF0dXMiPgogICAgICAgICAg
ICAgICAgPHNwYW4gaWQ9InN0dWIiPlBsZWFzZSB3YWl0LCBpdCB3aWxsIGJlIGF2YWlsYWJsZSBz
b29uPC9zcGFuPgogICAgICAgICAgICA8L2Rpdj4KICAgICAgICAgICAgPGRpdiBpZD0icmVzdWx0
Ij4KICAgICAgICAgICAgICAgIDxhIGlkPSJvcGVuIiBjbGFzcz0iaGlkZGVuIiBocmVmPSJqYXZh
c2NyaXB0OnJlbG9hZFBhZ2UoKSI+TG9naW4gdG8gVmVlYW0gUE48L2E+CiAgICAgICAgICAgIDwv
ZGl2PgogICAgICAgIDwvZGl2PgogICAgPC9ib2R5Pgo8L2h0bWw+CgAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAuL2Zhdmljb24uaWNvAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAMDAwMDY2NAAw
MDAxNzUwADAwMDE3NTQAMDAwMDAwMDIxNzYAMTM3NjY3MjEyNjQAMDEwMzA2ACAwAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAHVzdGFyICAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAQABABAQAAABACAAaAQAABYAAAAoAAAAEAAAACAAAAABACAAAAAAAEAEAAAAAAAAAAAA
AAAAAAAAAAAAWlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/
WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/2JZRv9dVED/XVRB/2JZRv9a
UT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/2JZRv+RjH7/+fn4//r6
+f+RjH7/YllG/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9bUj7/7Ovo
////////////7Ovo/1tSPv9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/
XlVC/93b1////////////93b1/9eVUL/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9a
UT3/WlE9/19WQ/9za1r/zsvF/83KxP9ya1r/X1ZD/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pR
Pf9aUT3/WlE9/1pRPf+WkIT/s66l/2xkUv9sZFL/s66l/5aQhP9aUT3/WlE9/1pRPf9aUT3/WlE9
/1pRPf9aUT3/WlE9/1pRPf9gV0T/7ezq/+ro5v9eVUL/XlVC/+ro5v/t7Or/YFdE/1pRPf9aUT3/
WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/qKSZ//////+SjH7/WlE9/1pRPf+SjH7//////6ikmf9a
UT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9iWkf/ZFtI/5CJfP/LyML/W1I+/1pRPf9aUT3/W1I+/8zJ
w/+QiXz/ZFtI/2NaR/9aUT3/WlE9/1pRPf9eVUH/s66l/9vZ1P+hm5D/Y1tI/1pRPf9aUT3/WlE9
/1pRPf9jWkj/oZuQ/9vZ1f+xraT/XlVB/1pRPf9cU0D/l5KF/////////////////3x0ZP+clor/
wr63/8K+t/+clov/fHRk/////////////////5eShf9cUz//XVRB/6SflP////////////////+L
hXf/tbGp//X19P/19fT/tbGp/4yFd/////////////////+loJX/XlVC/1pRPf9kXEn/4+He////
///S0Mv/XVVB/1pRPf9aUT3/WlE9/1pRPf9dVED/1NHM///////j4d7/Y1tI/1pRPf9aUT3/XVRB
/11VQf9iWUb/X1ZC/1tSPv9aUT3/WlE9/1pRPf9aUT3/W1I+/19WQv9iWUb/XVVB/11UQf9aUT3/
WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9aUT3/WlE9/1pRPf9a
UT3/WlE9/wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AC4vcnVubmluZy5naWYAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAwMDAwNjY0ADAwMDE3
NTAAMDAwMTc1NAAwMDAwMDAwMzQ3MQAxMzc2NjcyMTI2NAAwMTAzMzMAIDAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAdXN0YXIgIAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
R0lGODlhEAAQAPQAAOXl5TMzM9ra2pOTk8/Pz2NjY4eHhzMzM3BwcEtLS6urq7e3t0BAQJ+fnzU1
NVhYWHt7ewAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH/C05F
VFNDQVBFMi4wAwEAAAAh/hpDcmVhdGVkIHdpdGggYWpheGxvYWQuaW5mbwAh+QQJCgAAACwAAAAA
EAAQAAAFdyAgAgIJIeWoAkRCCMdBkKtIHIngyMKsErPBYbADpkSCwhDmQCBethRB6Vj4kFCkQPG4
IlWDgrNRIwnO4UKBXDufzQvDMaoSDBgFb886MiQadgNABAokfCwzBA8LCg0Egl8jAggGAA1kBIA1
BAYzlyILczULC2UhACH5BAkKAAAALAAAAAAQABAAAAV2ICACAmlAZTmOREEIyUEQjLKKxPHADhEv
qxlgcGgkGI1DYSVAIAWMx+lwSKkICJ0QsHi9RgKBwnVTiRQQgwF4I4UFDQQEwi6/3YSGWRRmjhEE
TAJfIgMFCnAKM0KDV4EEEAQLiF18TAYNXDaSe3x6mjidN1s3IQAh+QQJCgAAACwAAAAAEAAQAAAF
eCAgAgLZDGU5jgRECEUiCI+yioSDwDJyLKsXoHFQxBSHAoAAFBhqtMJg8DgQBgfrEsJAEAg4YhZI
EiwgKtHiMBgtpg3wbUZXGO7kOb1MUKRFMysCChAoggJCIg0GC2aNe4gqQldfL4l/Ag1AXySJgn5L
coE3QXI3IQAh+QQJCgAAACwAAAAAEAAQAAAFdiAgAgLZNGU5joQhCEjxIssqEo8bC9BRjy9Ag7GI
LQ4QEoE0gBAEBcOpcBA0DoxSK/e8LRIHn+i1cK0IyKdg0VAoljYIg+GgnRrwVS/8IAkICyosBIQp
BAMoKy9dImxPhS+GKkFrkX+TigtLlIyKXUF+NjagNiEAIfkECQoAAAAsAAAAABAAEAAABWwgIAIC
aRhlOY4EIgjH8R7LKhKHGwsMvb4AAy3WODBIBBKCsYA9TjuhDNDKEVSERezQEL0WrhXucRUQGuik
7bFlngzqVW9LMl9XWvLdjFaJtDFqZ1cEZUB0dUgvL3dgP4WJZn4jkomWNpSTIyEAIfkECQoAAAAs
AAAAABAAEAAABX4gIAICuSxlOY6CIgiD8RrEKgqGOwxwUrMlAoSwIzAGpJpgoSDAGifDY5kopBYD
lEpAQBwevxfBtRIUGi8xwWkDNBCIwmC9Vq0aiQQDQuK+VgQPDXV9hCJjBwcFYU5pLwwHXQcMKSmN
LQcIAExlbH8JBwttaX0ABAcNbWVbKyEAIfkECQoAAAAsAAAAABAAEAAABXkgIAICSRBlOY7CIghN
8zbEKsKoIjdFzZaEgUBHKChMJtRwcWpAWoWnifm6ESAMhO8lQK0EEAV3rFopIBCEcGwDKAqPh4HU
rY4ICHH1dSoTFgcHUiZjBhAJB2AHDykpKAwHAwdzf19KkASIPl9cDgcnDkdtNwiMJCshACH5BAkK
AAAALAAAAAAQABAAAAV3ICACAkkQZTmOAiosiyAoxCq+KPxCNVsSMRgBsiClWrLTSWFoIQZHl6pl
eBh6suxKMIhlvzbAwkBWfFWrBQTxNLq2RG2yhSUkDs2b63AYDAoJXAcFRwADeAkJDX0AQCsEfAQM
DAIPBz0rCgcxky0JRWE1AmwpKyEAIfkECQoAAAAsAAAAABAAEAAABXkgIAICKZzkqJ4nQZxLqZKv
4NqNLKK2/Q4Ek4lFXChsg5ypJjs1II3gEDUSRInEGYAw6B6zM4JhrDAtEosVkLUtHA7RHaHAGJQE
jsODcEg0FBAFVgkQJQ1pAwcDDw8KcFtSInwJAowCCA6RIwqZAgkPNgVpWndjdyohACH5BAkKAAAA
LAAAAAAQABAAAAV5ICACAimc5KieLEuUKvm2xAKLqDCfC2GaO9eL0LABWTiBYmA06W6kHgvCqEJi
AIJiu3gcvgUsscHUERm+kaCxyxa+zRPk0SgJEgfIvbAdIAQLCAYlCj4DBw0IBQsMCjIqBAcPAooC
Bg9pKgsJLwUFOhCZKyQDA3YqIQAh+QQJCgAAACwAAAAAEAAQAAAFdSAgAgIpnOSonmxbqiThCrJK
EHFbo8JxDDOZYFFb+A41E4H4OhkOipXwBElYITDAckFEOBgMQ3arkMkUBdxIUGZpEb7kaQBRlASP
g0FQQHAbEEMGDSVEAA1QBhAED1E0NgwFAooCDWljaQIQCE5qMHcNhCkjIQAh+QQJCgAAACwAAAAA
EAAQAAAFeSAgAgIpnOSoLgxxvqgKLEcCC65KEAByKK8cSpA4DAiHQ/DkKhGKh4ZCtCyZGo6F6iYY
PAqFgYy02xkSaLEMV34tELyRYNEsCQyHlvWkGCzsPgMCEAY7Cg04Uk48LAsDhRA8MVQPEF0GAgqY
YwSRlycNcWskCkApIyEAOwAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==

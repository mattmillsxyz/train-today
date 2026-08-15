#!/usr/bin/env bash
# Marketing app preview: six short beats cut together with transitions.
# Footage is real screen capture from the simulator; only the cuts,
# transitions and the slow push on the two static screens are added.
set -euo pipefail
cd /tmp/drillshots
rm -f m*.mp4 still_done.png still_progress2.png marketing-6.9.mp4 preview-886x1920.mp4

W=886; H=1920; FPS=30   # app preview spec (screenshots are 1320x2868)
DUR=3.4                      # each beat
XF=0.35                      # transition length
VF="fps=$FPS,scale=$W:$H:flags=lanczos,setsar=1,format=yuv420p"
ENC=(-c:v libx264 -preset slow -crf 18 -profile:v high -level 4.2 -pix_fmt yuv420p)

clip () { # clip <in> <start> <out>
  ffmpeg -v error -i "$1" -ss "$2" -t "$DUR" -vf "$VF" "${ENC[@]}" -an "$3"
}

# Beat 1: welcome screen, emoji drifting behind the wordmark
clip mk.mov 9.8  m1.mp4
# Beat 2: pick your sports, basketball and baseball chosen
clip mk.mov 57.0 m2.mp4
# Beat 3: today's session, tapping Start lifts the timer into place
clip mk.mov 163.0 m3.mp4
# Beat 4: the step timer counting down
clip mk.mov 191.2 m4.mp4

# Beat 5 and 6 are static screens, so give them a slow push for life.
ffmpeg -v error -i mk2.mov -ss 95.6 -frames:v 1 still_progress2.png
# Same exercise the timer beat shows, so the two beats read as one session.
cp raw/done_mc.png still_done.png

kenburns () { # kenburns <img> <out>
  local frames=$(python3 -c "print(int($DUR*$FPS))")
  ffmpeg -v error -loop 1 -framerate $FPS -i "$1" -frames:v "$frames" \
    -vf "scale=$W:$H:flags=lanczos,zoompan=z='min(zoom+0.00065,1.05)':d=1:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=${W}x${H}:fps=$FPS,setsar=1,format=yuv420p" \
    "${ENC[@]}" -an "$2"
}
kenburns still_done.png      m5.mp4
kenburns still_progress2.png m6.mp4

# Chain the six with xfades. Each offset is where the next beat starts
# blending in: cumulative (DUR - XF) per step.
O1=$(python3 -c "print(round($DUR-$XF,3))")
O2=$(python3 -c "print(round(2*($DUR-$XF),3))")
O3=$(python3 -c "print(round(3*($DUR-$XF),3))")
O4=$(python3 -c "print(round(4*($DUR-$XF),3))")
O5=$(python3 -c "print(round(5*($DUR-$XF),3))")

ffmpeg -v error -i m1.mp4 -i m2.mp4 -i m3.mp4 -i m4.mp4 -i m5.mp4 -i m6.mp4 \
  -filter_complex "\
[0][1]xfade=transition=slideleft:duration=$XF:offset=$O1[a]; \
[a][2]xfade=transition=smoothleft:duration=$XF:offset=$O2[b]; \
[b][3]xfade=transition=slideup:duration=$XF:offset=$O3[c]; \
[c][4]xfade=transition=circleopen:duration=$XF:offset=$O4[d]; \
[d][5]xfade=transition=slideleft:duration=$XF:offset=$O5,format=yuv420p[v]" \
  -map "[v]" "${ENC[@]}" -movflags +faststart preview-886x1920.mp4

ffprobe -v error -show_entries format=duration -show_entries stream=width,height,r_frame_rate,codec_name \
  -of default=noprint_wrappers=1 preview-886x1920.mp4
ls -la preview-886x1920.mp4

# Music pass. The source track is mastered hot (about -8.6 LUFS), so it is
# normalised to -16 LUFS before the fade, otherwise the preview is far louder
# than everything else on the App Store. Video is stream-copied, not re-encoded.
ffmpeg -v error -y -i preview-886x1920.mp4 -i prettyjohn1-sport-workout-gym-511260.mp3 \
  -filter_complex "[1:a]atrim=0:18.666667,asetpts=N/SR/TB,loudnorm=I=-16:TP=-1.5:LRA=11,afade=t=in:st=0:d=0.08,afade=t=out:st=15.9:d=2.75[a]" \
  -map 0:v -map "[a]" -c:v copy -c:a aac -b:a 192k -ar 44100 -ac 2 \
  -movflags +faststart preview-886x1920-music.mp4

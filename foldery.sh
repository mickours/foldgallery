#!/usr/bin/env bash
#
# Simple thumbnail picture gallery script.  With some Imagemagick transformations.
#
# ImageMadgick with SVG support is needed
#
# Based on the work of J McDonnell
#

set -o errno

folder=$1

if ! [[ -d "$folder" ]]
then
   echo "Argument missing (folder)"
   exit
fi

zipfile="$folder.zip"
thumbs="thumbs"
thumbs_abs_path="$PWD/$thumbs"
gallery="$folder.html"
root_path="$PWD"
img=$PWD
pictures=$(ls "$folder" | egrep -i "jpg$|jpeg$|mp4$|avi$" | egrep -v 'thumb')

#
# Process pictures, create thumbnails if necessary
#

# go in the folder
pushd "$folder"

for picture in $pictures
do
   echo Processing file $picture
   thumbpic="$thumbs_abs_path/${picture}_thumb.jpg"

   #
   # If no thumnail image exists for picture, create one...
   #
   if [ ! -f "$thumbpic" ]
   then
      pictitle=$(basename "$picture")
      is_video=""

      if $(file -i "$picture" | grep -q video);
      then
          ffmpeg -i "$picture" -t 2 -r 0.5 "$thumbpic"
          is_video=$picture
          picture=$thumbpic
      fi
      # Uncomment one of the four paragraphs below to achieve different effects.
      # (Only have one paragraph at a time uncommented).
      #


      # Option 1. Simple thumbnails with no effects.
      #echo convert "$picture" -resize 10% "$thumbpic"
      #convert "$picture" -resize 10% "$thumbpic"


      # Option 2. Put a simple frame around each picture, no caption.
      #echo montage -resize 10% -frame 5 -geometry +0+0 "$picture" "$thumbpic"
      #montage -resize 10% -frame 5 -geometry +0+0 "$picture" "$thumbpic"


      # Option 3. Put a simple frame round each picture with a caption at the bottom (-label)
      #echo montage -resize 10% -pointsize 20 -label "$pictitle" "$picture" -frame 5 -geometry +0+0 "$thumbpic"
      #montage -resize 10% -pointsize 20 -label "$pictitle" "$picture" -frame 5 -geometry +0+0 "$thumbpic"


      # Option 4. Put a "polaroid" effect on each picture, including a caption.  Picture is framed,
      # rotated with shadow.  If $angle is zero there is no rotation.
      # Note: the "-repage" is there to offet the rotated/"polaroided" within its actual
      # (unrotated) frame.  Without -repage, there is clipping where the shared/rotated 
      # image goes beyond the image border.
      #
      convert -thumbnail 300x300\> $picture png:small.png
      angle=$(($RANDOM % 20 - 10))
      #angle=0
      convert -set caption "$pictitle" small.png -pointsize 28 -background black -polaroid $angle -repage +10+5 png:polaroid.png
      convert polaroid.png -background white -flatten $thumbpic
      if ! [[ -z "$is_video" ]];
      then
          convert $thumbpic -background none -alpha on -page +1+1 $img/play.svg -flatten $thumbpic
      fi
   fi
done

rm -f polaroid.png small.png

# Create zipfile of all pics
if [ ! -f "$root_path/$zipfile" ]
then
   zip "$zipfile" $pictures
  mv "$zipfile" "$root_path"
fi


# go back to root_path
popd


###############################################################################
#
# Create index.html file

# get zipfile size
size=$(ls -lh "$zipfile" | awk '{print $5}')

cat > "$gallery" <<%
<html>
<head>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
</head>
<body>
<font face=arial size=6></font>
<h3>$folder</h3>
<p>Full album: <a href="$zipfile">"$zipfile"</a> ($size)</p>
%

for picture in $pictures
do
    thumbpic="$thumbs/${picture}_thumb.jpg"

    pictitle=$picture

    if $(file -i "$folder/$picture" | grep -q video);
    then
      # this is a video
      echo "<a href=\"$folder/$picture\"><img src="$thumbpic" alt=$thumbpic title=\"$pictitle\"></a>" >> "$gallery"
    else
      # this is an image
      echo "<a href=\"$folder/$picture\"><img src=$thumbpic alt=$thumbpic title=\"$pictitle\"></a>" >> "$gallery"
    fi
done

cat >> "$gallery" <<%
<p>Full album: <a href="$zipfile">"$zipfile"</a> ($size)</p>
<p><font face=arial size=2>Updated on $(date).  Run time $SECONDS seconds.</p>
</body>
</html>
%

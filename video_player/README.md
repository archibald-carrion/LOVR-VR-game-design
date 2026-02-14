## Step 1 - generate frames from a equirectangular video

### create the folder
mkdir frames
### create the frames
use the following to get the size, and if the video has 2 views then use htis information to calcualte the size of only the left eye
ffmpeg -i input.p4
and use this to actually extract the frames:
ffmpeg -i input.mp4 -vf "crop=2160:2160:0:0,scale=1536:1536,fps=30" -q:v 4 frames/frame_%05d.jpg


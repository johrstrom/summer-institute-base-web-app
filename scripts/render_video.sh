#!/bin/bash

module load ffmpeg/4.0.2

cd $OUTPUT_DIR

ffmpeg -r "$FRAMES_PER_SEC" -y -pattern_type glob -i "*.png" -vsync vfr -b:v 16M -pix_fmt yuv420p "video.mp4"



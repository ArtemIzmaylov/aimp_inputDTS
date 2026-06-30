#!/bin/sh

INCLUDES="-I/usr/include/cairo -I./aimp_sdk -I./aimp_sdk/Helpers -I./libdca"

INPUT=$(find ./ -name "*.cpp" -o -name "*.c")

LIBRARIES="-lpthread -lm -ldl -lstdc++ -static-libgcc"

FLAGS="-fPIC -Wno-attributes"

clear
echo "Assembling..."
gcc -shared -o ./aimp_inputDTS/x64/aimp_inputDTS.so $INCLUDES $FLAGS $INPUT $LIBRARIES
strip --strip-unneeded ./aimp_inputDTS/x64/aimp_inputDTS.so
echo "Done!"

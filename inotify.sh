#!/bin/sh

inotifywait -mr -e close_write src  | while read date time dir file; do
  ./bin/dev/compile_coffee
done


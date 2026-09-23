#!/bin/bash

xcodebuild \
  -project tab-flow-macos.xcodeproj \
  -scheme Debug \
  -configuration Debug \
  -derivedDataPath DerivedData

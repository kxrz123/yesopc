#!/bin/bash
# 从 logo/*.jpg 生成 iOS / Android / macOS 所需各尺寸图标
# 用法: ./generate_icons.sh [logo文件名，如 logo13.jpg，默认 logo14.jpg]
# 依赖: macOS 自带 sips

set -e
LOGO_NAME="${1:-logo14.jpg}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PROJECT_ROOT="$(cd "$APP_ROOT/../.." && pwd)"
SRC="$PROJECT_ROOT/logo/$LOGO_NAME"

IOS_ICONS="$APP_ROOT/ios/Runner/Assets.xcassets/AppIcon.appiconset"
MACOS_ICONS="$APP_ROOT/macos/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID_RES="$APP_ROOT/android/app/src/main/res"

if [ ! -f "$SRC" ]; then
  echo "找不到: $SRC"
  exit 1
fi
echo "源图: $SRC"

# 将 logo 完整放入正方形画布：黑底留白、不变形（用 pad 而非裁剪，避免裁掉 logo 部分）
SQUARE_SRC="/tmp/yesopc_logo_square_$$.png"
cleanup() { [ -f "$SQUARE_SRC" ] && rm -f "$SQUARE_SRC"; }
trap cleanup EXIT

W=$(sips -g pixelWidth  "$SRC" 2>/dev/null | awk '/pixelWidth:/{print $2}')
H=$(sips -g pixelHeight "$SRC" 2>/dev/null | awk '/pixelHeight:/{print $2}')
if [ -z "$W" ] || [ -z "$H" ]; then
  echo "无法读取图片尺寸，请确认 sips 可用"
  exit 1
fi
# 以长边为边长做正方形，短边方向用黑色留白，logo 完整居中显示
SIZE=$(( W >= H ? W : H ))
echo "原图 ${W}x${H} → 黑底留白为 ${SIZE}x${SIZE}（logo 完整、不变形）"
# sips padColor 需十六进制且对 PNG 可能无效，先留白输出 JPG 再转 PNG
PAD_JPG="${SQUARE_SRC%.png}.jpg"
sips -s format jpeg --padToHeightWidth "$SIZE" "$SIZE" --padColor 000000 "$SRC" --out "$PAD_JPG" 2>/dev/null || true
if [ -f "$PAD_JPG" ]; then
  sips -s format png "$PAD_JPG" --out "$SQUARE_SRC" 2>/dev/null
  rm -f "$PAD_JPG"
fi
if [ ! -f "$SQUARE_SRC" ]; then
  echo "留白失败，改用居中裁剪"
  SIZE=$(( W <= H ? W : H ))
  OX=$(( (W - SIZE) / 2 )); OY=$(( (H - SIZE) / 2 ))
  sips -s format png --cropToHeightWidth "$SIZE" "$SIZE" --cropOffset "$OX" "$OY" "$SRC" --out "$SQUARE_SRC" 2>/dev/null || true
fi
[ ! -f "$SQUARE_SRC" ] && { echo "无法生成正方形图"; exit 1; }
SRC="$SQUARE_SRC"

# 从正方形图生成 PNG，尺寸参数: 宽 高（均为像素）
gen() {
  local w=$1 h=${2:-$1}
  local out=$3
  mkdir -p "$(dirname "$out")"
  sips -s format png -z "$h" "$w" "$SRC" --out "$out" 2>/dev/null || true
  if [ -f "$out" ]; then echo "  $out"; fi
}

# ---------- iOS ----------
echo "[iOS] 生成 AppIcon..."
# 按实际像素生成，再复制到对应 filename
gen 20  20  "$IOS_ICONS/Icon-App-20x20@1x.png"
gen 40  40  "$IOS_ICONS/Icon-App-20x20@2x.png"
gen 60  60  "$IOS_ICONS/Icon-App-20x20@3x.png"
gen 29  29  "$IOS_ICONS/Icon-App-29x29@1x.png"
gen 58  58  "$IOS_ICONS/Icon-App-29x29@2x.png"
gen 87  87  "$IOS_ICONS/Icon-App-29x29@3x.png"
gen 40  40  "$IOS_ICONS/Icon-App-40x40@1x.png"
gen 80  80  "$IOS_ICONS/Icon-App-40x40@2x.png"
gen 120 120 "$IOS_ICONS/Icon-App-40x40@3x.png"
gen 120 120 "$IOS_ICONS/Icon-App-60x60@2x.png"
gen 180 180 "$IOS_ICONS/Icon-App-60x60@3x.png"
gen 76  76  "$IOS_ICONS/Icon-App-76x76@1x.png"
gen 152 152 "$IOS_ICONS/Icon-App-76x76@2x.png"
gen 167 167 "$IOS_ICONS/Icon-App-83.5x83.5@2x.png"
gen 1024 1024 "$IOS_ICONS/Icon-App-1024x1024@1x.png"

# ---------- macOS ----------
echo "[macOS] 生成 AppIcon..."
gen 16  16  "$MACOS_ICONS/app_icon_16.png"
gen 32  32  "$MACOS_ICONS/app_icon_32.png"
gen 64  64  "$MACOS_ICONS/app_icon_64.png"
gen 128 128 "$MACOS_ICONS/app_icon_128.png"
gen 256 256 "$MACOS_ICONS/app_icon_256.png"
gen 512 512 "$MACOS_ICONS/app_icon_512.png"
gen 1024 1024 "$MACOS_ICONS/app_icon_1024.png"

# ---------- Android mipmap ----------
echo "[Android] 生成 mipmap 图标..."
for dir in mipmap-mdpi mipmap-hdpi mipmap-xhdpi mipmap-xxhdpi mipmap-xxxhdpi; do
  case $dir in
    mipmap-mdpi)    s=48 ;;
    mipmap-hdpi)    s=72 ;;
    mipmap-xhdpi)   s=96 ;;
    mipmap-xxhdpi)  s=144 ;;
    mipmap-xxxhdpi) s=192 ;;
    *) exit 1 ;;
  esac
  mkdir -p "$ANDROID_RES/$dir"
  gen $s $s "$ANDROID_RES/$dir/ic_launcher.png"
  gen $s $s "$ANDROID_RES/$dir/launch_image.png"
done

echo "完成."

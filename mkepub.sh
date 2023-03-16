#!/bin/sh

# (http://hanamachi.com)
# Copyright Hanamachi 20230316 
# Licensed under the MIT license

#画像ファイルのリストを作成
if [[ ! -d "IMAGES" ]]; then
    if [[ -d "$1" ]]; then
        mv "$1" "IMAGES";
    fi
fi

cd IMAGES || exit
rm ._*

list=$(find . -type f -name "*.jpg";)

imgs=$(
    for i in "${list[@]}"; do
        echo "$i";
    done | sort
);
cd ../

#リストからファイル名のみを抽出
imgs=${imgs//\.jpg/}
imgs=${imgs//\.\//}

#テキスト書き出して配列として読み込む
cat <<EOF >.imagelist.txt
$imgs
EOF

imgs=($(cat .imagelist.txt|xargs))
rm ./.imagelist.txt

#表紙イメージ
cover="${imgs[0]}"
#メインページ
main="${imgs[1]}"
#ページカウント
pagecnt="$((${#imgs[@]} - 1))"
#日付
hiduke=$(date +%Y-%m-%d\ %H:%M:%S\ %Z)
#ブックID
etitle=$(echo "$1" | perl -MURI::Escape -lne 'print uri_escape($_)')
bookid=$(echo ${etitle//%/})

# ルートディリクトリに移動
# $1はスクリプト実施時に入力する書籍名です
mkdir "$1"
cd "$1" || exit

#mimetype設定
cat <<EOF > mimetype
application/epub+zip
EOF

#メタディリクトリ
mkdir META-INF
cd META-INF || exit
cat <<EOF > container.xml
<?xml version="1.0"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
<rootfiles>
<rootfile full-path="item/standard.opf" media-type="application/oebps-package+xml"/>
</rootfiles>
</container>
EOF
cd ../

# #コンテンツディリクトリ
mkdir item
cd item || exit
mv ../../IMAGES ./image

mkdir style
cd style || exit
cat <<EOF > fixed-layout-jp.css
@charset "UTF-8";
html,body {margin:0; padding:0; font-size:0;}
svg {margin:0; padding: 0;}
EOF
cd ../

images=$(
    for i in $(seq 1 "$pagecnt"); do
        echo '<item id="'"${imgs[$i]}"'" href="image/'"${imgs[$i]}"'.jpg" media-type="image/jpeg"/>';
    done
);
xhtml=$(
    for i in $(seq 1 "$pagecnt"); do
        echo '<item id="p-'"${imgs[$i]}"'" href="xhtml/p-'"${imgs[$i]}"'.xhtml" media-type="application/xhtml+xml" properties="svg"/>';
    done
);
spine=$(
    for i in $(seq 1 "$pagecnt"); do
        if [ $((${i} % 2)) = 1 ]; then
            echo '<itemref linear="yes" idref="p-'"${imgs[$i]}"'" properties="page-spread-left"/>';
        else
            echo '<itemref linear="yes" idref="p-'"${imgs[$i]}"'" properties="page-spread-right"/>';
        fi
    done
);

cat <<EOF > standard.opf
<?xml version="1.0" encoding="UTF-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0" xml:lang="ja" unique-identifier="unique-id" prefix="ebpaj: http://www.ebpaj.jp/">
<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
<dc:title id="title">$1</dc:title><!-- タイトル -->
<dc:publisher id="publisher">mk ePub shell</dc:publisher><!-- 出版社名 -->
<dc:language>ja</dc:language><!-- 言語 -->
<dc:identifier id="unique-id">urn:uuid:$bookid</dc:identifier>
<meta property="dcterms:modified">$hiduke</meta><!-- 更新日 -->
<meta property="ebpaj:guide-version">1.1.3</meta>
</metadata>
<manifest>
<!-- navigation -->
<item id="toc" href="navigation-documents.xhtml" media-type="application/xhtml+xml" properties="nav"/>
<!-- style -->
<item id="fixed-layout-jp" href="style/fixed-layout-jp.css" media-type="text/css"/>
<!-- images -->
<item id="$cover" href="image/$cover.jpg" media-type="image/jpeg" properties="cover-image"/>
$images
<!-- xhtml -->
<item id="p-cover" href="xhtml/p-cover.xhtml" media-type="application/xhtml+xml"/>
$xhtml
</manifest>
<!--spine -->
<spine page-progression-direction="rtl">
<itemref linear="yes" idref="p-cover" properties="rendition:page-spread-center"/>
$spine
</spine>
</package>
EOF

cat <<EOF > navigation-documents.xhtml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
<meta charset="UTF-8"/>
<title>$1</title>
</head>
<body>
<nav epub:type="toc" id="toc">
<h1>$1</h1>
<ol><li><a href="xhtml/p-cover.xhtml">$1</a></li></ol>
</nav>
</body>
</html>
EOF

mkdir xhtml
cd xhtml || exit

for i in $(seq 1 "$pagecnt"); do
cat <<EOF > p-"${imgs[$i]}".xhtml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
<meta charset="UTF-8"/>
<title>$1</title>
<link rel="stylesheet" type="text/css" href="../style/fixed-layout-jp.css"/>
<meta name="viewport" content="width=1414, height=2000"/>
</head>
<body>
<div class="main">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" width="100%" height="100%" viewBox="0 0 1414 2000">
<image width="1414" height="2000" xlink:href="../image/${imgs[$i]}.jpg"/>
</svg>
</div>
</body>
</html>
EOF
done

cat <<EOF > p-cover.xhtml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
<meta charset="UTF-8"/>
<title>$1</title>
<link rel="stylesheet" type="text/css" href="../style/fixed-layout-jp.css"/>
<meta name="viewport" content="width=1414, height=2000"/>
</head>
<body epub:type="cover">
<div class="main">
<svg xmlns="http://www.w3.org/2000/svg" version="1.1" xmlns:xlink="http://www.w3.org/1999/xlink" width="100%" height="100%" viewBox="0 0 1414 2000">
<image width="1414" height="2000" xlink:href="../image/$cover.jpg"/>
</svg>
</div>
</body>
</html>
EOF
cd ../../

cp item/image/$cover.jpg ./cover.jpg

zip -0 "$1".epub mimetype
zip -9r "$1".epub META-INF item cover.jpg

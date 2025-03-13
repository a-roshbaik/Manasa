#!/bin/bash

# تحديث النظام
echo "🔄 تحديث النظام..."
sudo apt update && sudo apt upgrade -y

# تثبيت المتطلبات الأساسية
echo "📦 تثبيت Node.js و npm..."
sudo apt install -y nodejs npm

# إصلاح أذونات npm
sudo mkdir -p /usr/local/lib/node_modules
sudo chown -R $USER /usr/local/lib/node_modules

# تثبيت Cordova و cordova-res
echo "⚡ تثبيت Cordova..."
npm install -g cordova cordova-res

# تثبيت Java
if ! command -v java &> /dev/null; then
    echo "☕ تثبيت Java 17..."
    sudo apt install -y openjdk-17-jdk
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Java مثبت: $(java -version 2>&1 | head -n 1)"
fi

# تثبيت Android SDK
if [ ! -d "$HOME/Android/Sdk" ]; then
    echo "📥 تثبيت Android SDK..."
    mkdir -p ~/Android
    cd ~/Android
    wget -q https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
    unzip -q commandlinetools-linux-9477386_latest.zip -d cmdline-tools
    mv cmdline-tools/cmdline-tools ~/Android/Sdk
    rm commandlinetools-linux-9477386_latest.zip
    echo 'export ANDROID_HOME=~/Android/Sdk' >> ~/.bashrc
    echo 'export PATH=$ANDROID_HOME/cmdline-tools/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Android SDK مثبت."
fi

# قبول التراخيص وتثبيت الأدوات
echo "📜 قبول تراخيص Android..."
yes | ~/Android/Sdk/cmdline-tools/bin/sdkmanager --licenses > /dev/null
echo "⚙️ تثبيت أدوات Android..."
~/Android/Sdk/cmdline-tools/bin/sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0"

# إنشاء مشروع Cordova
APP_DIR="MyApp"
if [ ! -d "$APP_DIR" ]; then
    echo "🚀 إنشاء مشروع Cordova جديد..."
    cordova create $APP_DIR com.example.myapp MyApp
else
    echo "✅ المشروع موجود مسبقًا: $APP_DIR"
fi

# الدخول إلى مجلد المشروع
cd $APP_DIR

# إضافة منصة Android (لإنشاء config.xml تلقائيًا)
if [ ! -d "platforms/android" ]; then
    echo "📱 إضافة منصة Android..."
    cordova platform add android@latest
else
    echo "✅ منصة Android موجودة مسبقًا."
fi

# التحقق من وجود config.xml
if [ ! -f "config.xml" ]; then
    echo "❌ خطأ: ملف config.xml غير موجود!"
    exit 1
fi

# منح صلاحيات الكتابة
echo "🔑 منح صلاحيات الكتابة..."
sudo chmod 777 config.xml
sudo chown $USER:$USER config.xml

# إضافة الأيقونات باستخدام sed مع تعبير نمطي قوي
echo "⚙️ تحديث ملف الإعدادات..."
# حذف أي إدخالات سابقة للأيقونة
sed -i '/<icon src="resources\/android\/icon.png" \/>/d' config.xml
sed -i '/<splash src="resources\/android\/splash.png" \/>/d' config.xml

# إضافة الإدخالات الجديدة
sed -i '/<platform[[:space:]]*name="android"[^>]*>/a \
    <icon src="resources\/android\/icon.png" \/>\
    <splash src="resources\/android\/splash.png" \/>' config.xml

# إعادة الصلاحيات الآمنة
sudo chmod 644 config.xml

# إنشاء مجلد الموارد
echo "📁 إنشاء مجلد الموارد..."
mkdir -p resources/android

# تحميل الأيقونات الأساسية
if [ ! -f "resources/android/icon.png" ]; then
    echo "🖼️ تحميل الأيقونة الافتراضية..."
    wget -q -O resources/android/icon.png https://raw.githubusercontent.com/ionic-team/ionic-resources/master/ionic-default-icon.png
fi

if [ ! -f "resources/android/splash.png" ]; then
    echo "🌄 تحميل شاشة البداية الافتراضية..."
    wget -q -O resources/android/splash.png https://raw.githubusercontent.com/ionic-team/ionic-resources/master/ionic-default-splash.png
fi

# التحقق من وجود الملفات
if [ ! -s "resources/android/icon.png" ] || [ ! -s "resources/android/splash.png" ]; then
    echo "❌ خطأ في تحميل الملفات!"
    exit 1
fi

# توليد الموارد
echo "🎨 توليد الموارد..."
cordova-res android --skip-config --copy --verbose

# بناء التطبيق كملف apk
echo "🏗️ بناء التطبيق كملف APK..."
cordova build android 

# عرض محتوى config.xml للتأكد
echo "📄 محتوى config.xml النهائي:"
cat config.xml

echo "🎉 اكتمل كل شيء بنجاح! ملف AAB جاهز في: platforms/android/app/build/outputs/bundle/release/"
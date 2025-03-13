#!/bin/bash

# تحديث قائمة الحزم
echo "🔄 تحديث الحزم..."
sudo apt update

# تثبيت Node.js و npm
echo "📦 التحقق من Node.js و npm..."
sudo apt install -y nodejs npm

# التحقق من تثبيت Java
if ! command -v java &> /dev/null
then
    echo "☕ Java غير مثبت، جاري التثبيت..."
    sudo apt install -y openjdk-17-jdk
    JAVA_HOME_PATH="/usr/lib/jvm/java-17-openjdk-amd64"
else
    JAVA_HOME_PATH=$(dirname $(dirname $(readlink -f $(which java))))
    echo "✅ Java مثبت: $(java -version)"
fi

echo "🔧 ضبط متغيرات البيئة لـ Java..."
export JAVA_HOME=$JAVA_HOME_PATH
export PATH=$JAVA_HOME/bin:$PATH
echo 'export JAVA_HOME='$JAVA_HOME_PATH >> ~/.bashrc
echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# تحديد مسار الأدوات داخل المجلد الحالي
CURRENT_DIR=$(pwd)
SDK_PATH="$CURRENT_DIR/AndroidSdk"

# التحقق من تثبيت Android SDK
if [ ! -d "$SDK_PATH" ]; then
    echo "📥 تثبيت Android SDK في $SDK_PATH..."
    mkdir -p "$SDK_PATH/cmdline-tools"
    wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O sdk-tools.zip
    unzip sdk-tools.zip -d "$SDK_PATH/cmdline-tools"
    mv "$SDK_PATH/cmdline-tools/cmdline-tools" "$SDK_PATH/cmdline-tools/latest"
    rm sdk-tools.zip
else
    echo "✅ Android SDK مثبت في $SDK_PATH."
fi

echo "🔧 ضبط متغيرات البيئة لـ Android SDK..."
export ANDROID_HOME=$SDK_PATH
export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH
echo 'export ANDROID_HOME='$ANDROID_HOME >> ~/.bashrc
echo 'export PATH=$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$ANDROID_HOME/build-tools/34.0.0:$PATH' >> ~/.bashrc
source ~/.bashrc

# تثبيت الأدوات المطلوبة داخل SDK مع تحديد إصدار Android 34
echo "⚙️ تثبيت أدوات Android SDK..."
yes | sdkmanager --licenses
sdkmanager --install "platform-tools" "platforms;android-34" "build-tools;34.0.0" "cmdline-tools;latest"

# التحقق من تثبيت Gradle
if ! command -v gradle &> /dev/null
then
    echo "📥 تثبيت Gradle..."
    sudo apt install -y gradle
else
    echo "✅ Gradle مثبت: $(gradle -v | head -n 1)"
fi

# التحقق من تثبيت Cordova
if ! command -v cordova &> /dev/null
then
    echo "📥 تثبيت Cordova..."
    npm install -g cordova
else
    echo "✅ Cordova مثبت."
fi

# تحديد مسار المشروع ليكون داخل المجلد الحالي
APP_PATH="$CURRENT_DIR/MyApp"

if [ ! -d "$APP_PATH" ]; then
    echo "📦 إنشاء مشروع Cordova في $APP_PATH..."
    cordova create "$APP_PATH" com.example.hello HelloWorld
fi

# ضبط الصلاحيات لمنع أخطاء EACCES
echo "🔑 ضبط الصلاحيات..."
sudo chmod -R 777 "$APP_PATH"
sudo chown -R $USER:$USER "$APP_PATH"

# الدخول إلى مجلد المشروع
cd "$APP_PATH"

# إضافة منصة Android بإصدار 34
cordova platform add android@latest

# عرض المنصات المتاحة
cordova platform ls

# بناء التطبيق
echo "⚒️ بناء التطبيق..."
cordova build android

# تشغيل التطبيق على الجهاز
echo "📱 تشغيل التطبيق على الهاتف..."
cordova run android

# تشغيل التطبيق على المحاكي
echo "🖥️ تشغيل التطبيق على المحاكي..."
cordova emulate android

echo "🎉 تم الانتهاء بنجاح!"

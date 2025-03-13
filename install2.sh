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
    echo 'export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64' >> ~/.bashrc
    echo 'export PATH=$JAVA_HOME/bin:$PATH' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Java مثبت: $(java -version)"
fi

# التحقق من تثبيت Android SDK
if [ ! -d "$HOME/Android/Sdk" ]; then
    echo "📥 تثبيت Android SDK..."
    mkdir -p "$HOME/Android"
    cd "$HOME/Android"
    wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip
    unzip commandlinetools-linux-9477386_latest.zip -d cmdline-tools
    mv cmdline-tools/cmdline-tools "$HOME/Android/Sdk"
    rm -rf commandlinetools-linux.zip
    echo 'export ANDROID_HOME=$HOME/Android/Sdk' >> ~/.bashrc
    echo 'export PATH=$ANDROID_HOME/cmdline-tools/bin:$ANDROID_HOME/platform-tools:$PATH' >> ~/.bashrc
    source ~/.bashrc
else
    echo "✅ Android SDK مثبت."
fi

# تثبيت الأدوات المطلوبة داخل SDK
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

# التحقق من تثبيت cordova-res
if ! command -v cordova-res &> /dev/null
then
    echo "📥 تثبيت cordova-res..."
    npm install -g cordova-res
else
    echo "✅ cordova-res مثبت."
fi

# إنشاء مشروع Cordova
APP_PATH="$(pwd)/MyApp"

if [ ! -d "$APP_PATH" ]; then
    echo "📦 إنشاء مشروع Cordova..."
    cordova create "$APP_PATH" com.example.hello HelloWorld
fi

# ضبط الصلاحيات لمنع أخطاء EACCES
echo "🔑 ضبط الصلاحيات..."
sudo chmod -R 777 "$APP_PATH"
sudo chown -R $USER:$USER "$APP_PATH"

# الدخول إلى مجلد المشروع
cd "$APP_PATH"

# التحقق من وجود ملف config.xml وإنشاؤه أو تعديله لإضافة الأيقونة وصورة الـ Splash
if [ ! -f "config.xml" ]; then
    echo "📝 إنشاء ملف config.xml..."
    cat <<EOL > config.xml
<?xml version='1.0' encoding='utf-8'?>
<widget id="com.example.hello" version="1.0.0" xmlns="http://www.w3.org/ns/widgets" xmlns:gap="http://phonegap.com/ns/1.0">
    <name>HelloWorld</name>
    <description>My Cordova App</description>

    <platform name="android">
        <icon src="resources/android/icon.png" />
        <splash src="resources/android/splash.png" />
    </platform>
</widget>
EOL
else
    echo "⚙️ تحديث config.xml لإضافة الأيقونة وصورة الـ Splash..."
    
    # إزالة أي سطور قديمة للأيقونة أو السبلاش لتجنب التكرار
    sed -i '/<icon src="resources\/android\/icon.png" \/>/d' config.xml
    sed -i '/<splash src="resources\/android\/splash.png" \/>/d' config.xml

    # إدراج السطور الجديدة بعد `<platform name="android">`
    sed -i '/<platform name="android">/a \        <icon src="resources/android/icon.png" />\n        <splash src="resources/android/splash.png" />' config.xml
fi



# إنشاء مجلد الموارد إذا لم يكن موجودًا
mkdir -p resources/android

# وضع أيقونة افتراضية إذا لم تكن موجودة
if [ ! -f "resources/android/icon.png" ]; then
    echo "🖼️ تحميل أيقونة افتراضية..."
    wget -O resources/android/icon.png https://via.placeholder.com/512
fi

# وضع صورة Splash افتراضية إذا لم تكن موجودة
if [ ! -f "resources/android/splash.png" ]; then
    echo "🖼️ تحميل صورة Splash افتراضية..."
    wget -O resources/android/splash.png https://via.placeholder.com/1920
fi

# تشغيل cordova-res لإنشاء الأيقونات وصور الـ Splash
echo "⚒️ إنشاء الأيقونات وصور الـ Splash..."
cordova-res android --skip-config --copy

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

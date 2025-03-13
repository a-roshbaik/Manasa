from flask import Flask, request, jsonify, send_from_directory, send_file
import sqlite3
import subprocess
import os
import shutil
import json
import logging
from flask_caching import Cache  # pip3 install flask-caching
import re

app = Flask(__name__)

# إعداد التخزين المؤقت
cache = Cache(app, config={'CACHE_TYPE': 'simple'})

# إعداد التسجيل
logging.basicConfig(filename='app.log', level=logging.INFO, 
                    format='%(asctime)s - %(levelname)s - %(message)s')

# مسارات المشروع
SHARED_PROJECT_PATH = os.path.join(os.path.dirname(__file__), 'MyApp')
APK_STORAGE_PATH = os.path.join(os.path.dirname(__file__), 'apks')
ICON_PATH = os.path.join(os.path.dirname(__file__), 'icons')
DB_PATH = os.path.join(os.path.dirname(__file__), 'apps.db')  # مسار ثابت لقاعدة البيانات

# التأكد من وجود مجلد APK
if not os.path.exists(APK_STORAGE_PATH):
    os.makedirs(APK_STORAGE_PATH, exist_ok=True)

# إعداد قاعدة البيانات
def init_db():
    """تهيئة قاعدة البيانات وإنشاء جدول apps إذا لم يكن موجودًا."""
    try:
        with sqlite3.connect(DB_PATH) as conn:
            c = conn.cursor()
            c.execute('''CREATE TABLE IF NOT EXISTS apps
                         (id INTEGER PRIMARY KEY AUTOINCREMENT,
                          app_name TEXT NOT NULL,
                          package_name TEXT NOT NULL,
                          icon TEXT,
                          activity_type TEXT,
                          elements TEXT)''')
            conn.commit()
        logging.info("تم إنشاء أو التحقق من جدول apps بنجاح في apps.db")
    except sqlite3.Error as e:
        logging.error(f"خطأ أثناء تهيئة قاعدة البيانات: {str(e)}")
        raise  # إيقاف التطبيق إذا فشلت التهيئة
    except Exception as e:
        logging.error(f"خطأ غير متوقع أثناء تهيئة قاعدة البيانات: {str(e)}")
        raise

# استدعاء init_db عند بدء التطبيق
init_db()

def update_config_xml(app_name, package_name):
    config_path = os.path.join(SHARED_PROJECT_PATH, 'config.xml')
    if not os.path.exists(config_path):
        logging.error(f"ملف config.xml غير موجود في {config_path}")
        raise FileNotFoundError(f"ملف config.xml غير موجود في {config_path}")

    try:
        # نص XML خام بدون <splash> ومع التحقق من الأيقونة
        config_content = f'''<?xml version='1.0' encoding='utf-8'?>
<widget id="{package_name}" version="1.0.0" xmlns="http://www.w3.org/ns/widgets" xmlns:cdv="http://cordova.apache.org/ns/1.0">
    <name>{app_name}</name>
    <description>Sample Apache Cordova App</description>
    <author email="dev@cordova.apache.org" href="https://cordova.apache.org">
        Apache Cordova Team
    </author>
    <content src="index.html" />
    <allow-intent href="http://*/*" />
    <allow-intent href="https://*/*" />
    <platform name="android">
'''
        # إضافة الأيقونة فقط إذا كانت موجودة
        icon_path = os.path.join(SHARED_PROJECT_PATH, 'resources', 'android', 'icon.png')
        if os.path.exists(icon_path):
            config_content += '        <icon src="resources/android/icon.png" />\n'
        # استبدال <splash> بـ <preference>
        config_content += '''        <preference name="AndroidWindowSplashScreenAnimatedIcon" value="resources/android/splash.png" />
        <preference name="AndroidWindowSplashScreenBackground" value="#ffffff" />
    </platform>
</widget>'''

        # كتابة الملف مباشرة
        with open(config_path, 'w', encoding='utf-8') as f:
            f.write(config_content)
        logging.info(f"تم تعديل config.xml بنجاح: id={package_name}, name={app_name}")
    except Exception as e:
        logging.error(f"خطأ أثناء تعديل config.xml: {str(e)}")
        raise


@app.route('/')
def serve_input():
    return send_from_directory('static', 'input.html')

@app.route('/save_app_data', methods=['POST'])
def save_app_data():
    try:
        data = request.get_json()
        app_name = data.get('appName', '').strip()
        package_name = data.get('packageName', '').strip()
        icon = data.get('icon', '')
        activity_type = data.get('activityType', '')
        elements = data.get('elements', [])

        # التحقق من صحة البيانات
        if not app_name or not package_name:
            return jsonify({'status': 'error', 'message': 'اسم التطبيق أو الحزمة مطلوب'}), 400
        if not re.match(r'^[a-zA-Z0-9][a-zA-Z0-9\.]*[a-zA-Z0-9]$', package_name) or len(package_name.split('.')) < 2:
            return jsonify({'status': 'error', 'message': 'اسم الحزمة غير صالح (مثال: com.example.app)'}), 400

        elements_json = json.dumps(elements)

        with sqlite3.connect(DB_PATH) as conn:
            c = conn.cursor()
            c.execute("INSERT INTO apps (app_name, package_name, icon, activity_type, elements) VALUES (?, ?, ?, ?, ?)",
                      (app_name, package_name, icon, activity_type, elements_json))
            app_id = c.lastrowid
            conn.commit()

        logging.info(f"تم حفظ بيانات التطبيق بنجاح - ID: {app_id}")
        return jsonify({'status': 'success', 'app_id': app_id})
    except sqlite3.Error as e:
        logging.error(f"خطأ في قاعدة البيانات أثناء حفظ البيانات: {str(e)}")
        return jsonify({'status': 'error', 'message': f'حدث خطأ في قاعدة البيانات: {str(e)}'}), 500
    except Exception as e:
        logging.error(f"خطأ أثناء حفظ البيانات: {str(e)}")
        return jsonify({'status': 'error', 'message': f'حدث خطأ: {str(e)}'}), 500

@app.route('/build_app/<int:app_id>', methods=['GET'])
def build_app(app_id):
    try:
        apk_path = os.path.join(APK_STORAGE_PATH, f'{app_id}.apk')
        if os.path.exists(apk_path):
            logging.info(f"إرجاع ملف APK موجود مسبقًا - ID: {app_id}")
            return send_file(apk_path, as_attachment=True, download_name=f'app_{app_id}.apk')

        with sqlite3.connect(DB_PATH) as conn:
            c = conn.cursor()
            c.execute("SELECT * FROM apps WHERE id = ?", (app_id,))
            app_data = c.fetchone()

        if not app_data:
            return jsonify({'status': 'error', 'message': 'التطبيق غير موجود'}), 404

        app_name, package_name, icon, activity_type, elements = app_data[1], app_data[2], app_data[3], app_data[4], json.loads(app_data[5])
        
        # تعديل config.xml
        update_config_xml(app_name, package_name)
        
        # تغيير المسار إلى مجلد المشروع
        os.chdir(SHARED_PROJECT_PATH)
        
        # إزالة منصة Android مع التقاط المخرجات
        remove_process = subprocess.run(['cordova', 'platform', 'remove', 'android'], 
                                        capture_output=True, text=True, check=False)  # check=False عشان نكمل حتى لو فشل
        logging.info(f"مخرجات إزالة المنصة: {remove_process.stdout}")
        if remove_process.stderr:
            logging.error(f"أخطاء إزالة المنصة: {remove_process.stderr}")
        
        # التحقق من إزالة المنصة
        platform_check = subprocess.run(['cordova', 'platform', 'ls'], 
                                        capture_output=True, text=True, check=True)
        logging.info(f"المنصات الموجودة بعد الإزالة: {platform_check.stdout}")
        
        # إعادة إضافة منصة Android مع التقاط المخرجات
        add_process = subprocess.run(['cordova', 'platform', 'add', 'android'], 
                                     capture_output=True, text=True, check=True)
        logging.info(f"مخرجات إضافة المنصة: {add_process.stdout}")
        if add_process.stderr:
            logging.error(f"أخطاء إضافة المنصة: {add_process.stderr}")
        
        # تعديل ملف index.html
        index_path = os.path.join(SHARED_PROJECT_PATH, 'www', 'index.html')
        with open(index_path, 'w') as f:
            f.write('<!DOCTYPE html>\n<html>\n<head>\n<meta charset="UTF-8">\n<title>{}</title>\n'.format(app_name))
            f.write('<style>\n')
            f.write('html, body { height: 100%; margin: 0; padding: 0; }\n')
            f.write('iframe { width: 100%; height: 100%; border: none; }\n')
            f.write('\n</style>\n</head>\n<body>\n')
            for element in elements:
                if element == 'text':
                    f.write('<p>نص تجريبي</p>\n')
                elif isinstance(element, dict) and element['type'] == 'webview':
                    if element['webviewType'] == 'url':
                        f.write(f'<iframe src="{element["content"]}"></iframe>\n')
                    elif element['webviewType'] == 'html':
                        f.write(element['content'] + '\n')
            f.write('</body>\n</html>')

        # نسخ الأيقونة
        icon_source_path = os.path.join(ICON_PATH, f"{icon}.png")
        icon_dest_path = os.path.join(SHARED_PROJECT_PATH, 'resources', 'android', 'icon.png')
        if os.path.exists(icon_source_path):
            os.makedirs(os.path.dirname(icon_dest_path), exist_ok=True)
            shutil.copy(icon_source_path, icon_dest_path)
            logging.info(f"تم نسخ الأيقونة {icon_source_path} إلى {icon_dest_path}")
        else:
            logging.warning(f"الأيقونة {icon_source_path} غير موجودة، سيتم استخدام الأيقونة الافتراضية")

        # بناء التطبيق مع التقاط المخرجات
        build_process = subprocess.run(['cordova', 'build', 'android'], 
                                       capture_output=True, text=True, check=True)
        logging.info(f"مخرجات بناء التطبيق: {build_process.stdout}")
        if build_process.stderr:
            logging.error(f"أخطاء بناء التطبيق: {build_process.stderr}")

        # نقل ملف APK
        built_apk_path = os.path.join(SHARED_PROJECT_PATH, 'platforms', 'android', 'app', 'build', 'outputs', 'apk', 'debug', 'app-debug.apk')
        shutil.copy(built_apk_path, apk_path)

        # تنظيف الملفات المؤقتة
        temp_build_path = os.path.join(SHARED_PROJECT_PATH, 'platforms', 'android', 'app', 'build')
        shutil.rmtree(temp_build_path, ignore_errors=True)

        logging.info(f"تم بناء التطبيق بنجاح - ID: {app_id}")
        return send_file(apk_path, as_attachment=True, download_name=f'{app_name}.apk')
    except subprocess.CalledProcessError as e:
        logging.error(f"فشل بناء التطبيق - ID: {app_id}, خطأ: {str(e)}")
        logging.error(f"مخرجات الأمر: {e.stdout}")
        logging.error(f"أخطاء الأمر: {e.stderr}")
        return jsonify({'status': 'error', 'message': f'فشل بناء التطبيق: {e.stderr}'}), 500
    except Exception as e:
        logging.error(f"خطأ أثناء بناء التطبيق - ID: {app_id}: {str(e)}")
        return jsonify({'status': 'error', 'message': f'حدث خطأ: {str(e)}'}), 500
@app.route('/apks/<filename>')
def serve_apk(filename):
    try:
        return send_from_directory(APK_STORAGE_PATH, filename, as_attachment=True)
    except FileNotFoundError:
        return jsonify({'status': 'error', 'message': 'الملف غير موجود'}), 404

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
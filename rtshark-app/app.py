from flask import Flask, render_template, request, redirect, url_for, flash, send_from_directory, session
from flask_login import LoginManager, login_user, logout_user, login_required, current_user
import subprocess
import configparser
import os
from datetime import datetime
from werkzeug.middleware.proxy_fix import ProxyFix
from functools import wraps
from models import User, users
import logging
from logging.handlers import RotatingFileHandler
from ansi2html import Ansi2HTMLConverter

def setup_logging():
    log_format = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s")
    handler = RotatingFileHandler('/var/log/rtshark-app/inapplog.log', maxBytes=10000, backupCount=1)
    handler.setFormatter(log_format)
    handler.setLevel(logging.INFO) 
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.INFO)




app = Flask(__name__)
app.secret_key = '561c2fef765bd8f50a5253ac1a4fe77259d86d09e98a05d8176a23d8300202ea'  # Replace with a real secret key
app.wsgi_app = ProxyFix(app.wsgi_app)
setup_logging()
# Flask-Login setup
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.session_protection = "strong"  # or None
login_manager.login_view = 'login'
app.config['SESSION_COOKIE_SECURE'] = True
app.config['REMEMBER_COOKIE_SECURE'] = True

@login_manager.user_loader
def load_user(user_id):
    for user in users:
        app.logger.info("in the load_user for user:" + user.username)
        if user.id == int(user_id):
            app.logger.info("returning user")
            return user
    app.logger.info("returning none")
    return None


@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        app.logger.info(username + ":" + password)
        for user in users:
            app.logger.info(user.username + ":" + user.password)
            if user.username == username and user.password == password:
                app.logger.info("Should Login")
                login_user(user, remember=True)
                app.logger.info(f"LOGIN_USER Current user authenticated: {current_user.is_authenticated}")
                return redirect(url_for('index'))
        flash('Invalid credentials')
    return render_template('login.html')


@app.route('/logout')
def logout():
    logout_user()
    return redirect(url_for('login'))

# def login_required(f):
#     @wraps(f)
#     def decorated_function(*args, **kwargs):
#         if 'username' not in session:
#             return redirect(url_for('login'))
#         return f(*args, **kwargs)
#     return decorated_function

def set_filter(ip_address):
    # Set the IP filter for tshark
    # This might involve editing a configuration file or passing arguments to the service
    pass

def get_selected_ips():
    config = configparser.ConfigParser()
    config.read('.config/tshark_filter.ini')
    if 'Tshark' in config and 'IPAddresses' in config['Tshark']:
        return config['Tshark']['IPAddresses'].split(',')
    return []
def control_service(action):
    if action == "Start Service":
        # Start the tshark service
        subprocess.run(["sudo", "systemctl", "start", "tshark.service"])
    elif action == "Stop Service":
        # Stop the tshark service
        subprocess.run(["sudo", "systemctl", "stop", "tshark.service"])


def set_filter(ip_addresses):
    config = configparser.ConfigParser()
    config['Tshark'] = {'IPAddresses': ','.join(ip_addresses)}

    with open('.config/tshark_filter.ini', 'w') as configfile:
        config.write(configfile)



@app.route('/control_service', methods=['POST'])
@login_required
def handle_control_service():
    action = request.form['action']
    control_service(action)
    return redirect(url_for('index'))

@app.route('/set_filter', methods=['POST'])
@login_required
def handle_set_filter():
    # Check if tshark service is running
    result = subprocess.run(["sudo", "systemctl", "status", "tshark.service"], capture_output=True, text=True)
    if 'active (running)' in result.stdout:
        # If running, return an error message
        flash('You must first stop the capture service to change the filter.')
        return redirect(url_for('index'))

    selected_ips = request.form.getlist('ip_addresses')
    set_filter(selected_ips)
    flash(f"Selected IP Addresses: {', '.join(selected_ips)}")
    return redirect(url_for('index'))


# @app.route('/status')
# @login_required
# def service_status():
#     result = subprocess.run(["sudo", "systemctl", "status", "tshark.service"], capture_output=True, text=True)
#     status_simple = 'Running' if 'active (running)' in result.stdout else 'Stopped'
#     return {'status_simple': status_simple, 'status_detail': result.stdout}


@app.route('/status')
@login_required
def service_status():
    result = subprocess.run(["sudo", "systemctl", "status", "tshark.service", "--no-pager"], capture_output=True, text=True)
    app.logger.info(result)
    conv = Ansi2HTMLConverter()
    html_output = conv.convert(result.stdout, full=False)
    status_simple = 'Running' if 'active (running)' in result.stdout else 'Stopped'

    if 'full' in request.args:
        # Render the full status page
        return render_template('status.html', status_output=html_output)
    else:
        # Return simple status as JSON
        return {'status_simple': status_simple, 'status_detail': result.stdout}

@app.route('/list_captures')
@login_required
def list_captures():
    capture_directory = '/captures'
    capture_files = []
    for file in os.listdir(capture_directory):
        file_path = os.path.join(capture_directory, file)
        if os.path.isfile(file_path):
            file_stats = os.stat(file_path)
            capture_files.append({
                'name': file,
                'size': round(file_stats.st_size / (1024 * 1024), 2),  # Convert size from bytes to MB
                'mtime': datetime.fromtimestamp(file_stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
            })
    return render_template('list_captures.html', capture_files=capture_files)

@app.route('/download/<filename>')
@login_required
def download_file(filename):
    return send_from_directory('/captures', filename, as_attachment=True)

@app.route('/')
@login_required
def index():
    app.logger.info(f"Current user authenticated: {current_user.is_authenticated}")
    selected_ips = get_selected_ips()
    return render_template('index.html', selected_ips=selected_ips)


@app.route('/test')
@login_required
def test():
    return "Test Page - Logged in as: " + current_user.username

if __name__ == '__main__':
    app.run(debug=True)




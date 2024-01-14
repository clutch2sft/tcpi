import os
from flask import Flask
from flask_login import UserMixin

app = Flask(__name__)
# your Flask app configuration

class User(UserMixin):
    def __init__(self, id, username, password):
        self.id = id
        self.username = username
        self.password = password
    def get_id(self):
        return str(self.id)

# Read environment variables for passwords
admin_password = os.environ.get('ADMIN_PASSWORD', 'default_password_if_not_set')

# Example user with password from environment variable
users = [User(1, 'admin', admin_password)]

from flask import Flask
import os
import psycopg2

app = Flask(__name__)

@app.route('/')
def index():
    db_host = os.getenv('DB_HOST')
    db_user = os.getenv('DB_USER')
    db_pass = os.getenv('DB_PASS')
    db_name = os.getenv('DB_NAME')

    try:
        conn = psycopg2.connect(
            host=db_host,
            user=db_user,
            password=db_pass,
            dbname=db_name
        )
        cursor = conn.cursor()
        cursor.execute("SELECT 'Hello from RDS!'")
        result = cursor.fetchone()
        return result[0]
    except Exception as e:
        return f"Error connecting to DB: {e}"

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)


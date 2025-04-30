from flask import Flask
import os

app = Flask(__name__)

@app.route("/")
def home():
    return "My Python App on GKE has been updated via CI/CD!"

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    # Run on 0.0.0.0 to be accessible within Docker later
    app.run(debug=True, host='0.0.0.0', port=port)
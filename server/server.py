import os
import base64
import re
import json
from dotenv import load_dotenv
from flask import Flask, request, jsonify
import openai
import cloudinary
import cloudinary.uploader
import time
import hmac
import hashlib

app = Flask(__name__)

# Load credentials
load_dotenv(dotenv_path="secrets.env")
openai.api_key = os.getenv("OPENAI_API_KEY")

cloudinary.config(
    cloud_name=os.getenv("CLOUDINARY_CLOUD_NAME"),
    api_key=os.getenv("CLOUDINARY_API_KEY"),
    api_secret=os.getenv("CLOUDINARY_API_SECRET")
)

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        data = request.get_json(force=True)
        image_b64 = data.get("image")
        if not image_b64:
            return jsonify({"error": "No image provided"}), 400

        # Decode and save image
        try:
            image_bytes = base64.b64decode(image_b64)
        except Exception:
            return jsonify({"error": "Invalid base64 image"}), 400

        temp_filename = "temp.jpg"
        with open(temp_filename, "wb") as f:
            f.write(image_bytes)

        # Upload to Cloudinary
        try:
            upload_result = cloudinary.uploader.upload(temp_filename)
            image_url = upload_result.get("secure_url")
        except Exception as e:
            return jsonify({"error": "Cloudinary upload failed", "details": str(e)}), 500
        finally:
            if os.path.exists(temp_filename):
                os.remove(temp_filename)

        if not image_url:
            return jsonify({"error": "Image upload did not return a URL."}), 500

        # --- Dish name ---
        try:
            name_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a culinary expert. Return ONLY a JSON object like: "
                            "{\"title\": \"Chicken Alfredo\"}. No intro, no explanation, just the JSON."
                        )
                    },
                    {
                        "role": "user",
                        "content": [
                            {"type": "text", "text": "What is the name of this dish? Return only JSON."},
                            {"type": "image_url", "image_url": {"url": image_url}}
                        ]
                    }
                ],
                max_tokens=100,
                timeout=30
            )
            raw_json = name_response.choices[0].message.content.strip()
            print(f"Raw GPT JSON response: {raw_json}")

            try:
                parsed = json.loads(raw_json)
                dish_name = (
                        parsed.get("title")
                        or parsed.get("dish_name")
                        or ""
                ).strip()
            except json.JSONDecodeError:
                dish_name = ""

            match = re.search(r"([A-Z][a-zA-Z\s\-']{2,50})", dish_name)
            if match:
                dish_name = match.group(0).strip()

            if not dish_name or dish_name.lower() in {"dish", "food", "unknown", "none"}:
                dish_name = "Unknown Dish"

        except Exception as e:
            print("🔥 Error during dish name generation:", e)
            dish_name = "Unknown Dish"

        print(f"✅ Parsed dish name: '{dish_name}'")

        # --- Dish description ---
        try:
            desc_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a culinary expert. Write an accurate description describing the dish you see in the image. "
                            "Mention ingredients, flavors, and textures."
                        )
                    },
                    {
                        "role": "user",
                        "content": f"Describe the dish '{dish_name}' in two clean and precise yet descriptive sentences."
                    }
                ],
                max_tokens=300,
                timeout=30
            )
            description = desc_response.choices[0].message.content.strip()
        except Exception as e:
            print("🔥 Error during description:", e)
            description = "No description available."

        # --- Healthier Recipe (structured) ---
        try:
            healthy_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a professional chef and nutritionist. Generate a structured JSON for a healthier version of the given dish. "
                            "JSON format only. No markdown or explanations. Format:\n"
                            "{"
                            "\"title\": \"string\", "
                            "\"ingredients\": [\"string\"], "
                            "\"instructions\": [\"string\"], "
                            "\"servings\": int, "
                            "\"prepTime\": \"string\", "
                            "\"cookTime\": \"string\", "
                            "\"nutrition\": {\"calories\": int, \"protein\": \"string\", \"carbs\": \"string\", \"fat\": \"string\"}"
                            "}"
                        )
                    },
                    {
                        "role": "user",
                        "content": f"Give a healthier recipe for the '{dish_name}' that you see in the image with that exact JSON structure only."
                    }
                ],
                max_tokens=1000,
                timeout=60
            )
            healthy_raw = healthy_response.choices[0].message.content.strip()
            healthy_recipe = json.loads(healthy_raw)
        except Exception as e:
            print("🔥 Error during healthy recipe:", e)
            healthy_recipe = {
                "title": "Healthy Version",
                "ingredients": [],
                "instructions": [],
                "servings": 0,
                "prepTime": "",
                "cookTime": "",
                "nutrition": {}
            }

        # --- Mimic Recipe (structured) ---
        try:
            mimic_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {
                        "role": "system",
                        "content": (
                            "You are a professional chef. Generate a structured JSON recipe that closely mimics the original dish. "
                            "JSON format only. No markdown or hashtags. Format:\n"
                            "{"
                            "\"title\": \"string\", "
                            "\"ingredients\": [\"string\"], "
                            "\"instructions\": [\"string\"], "
                            "\"servings\": int, "
                            "\"prepTime\": \"string\", "
                            "\"cookTime\": \"string\", "
                            "\"nutrition\": {\"calories\": int, \"protein\": \"string\", \"carbs\": \"string\", \"fat\": \"string\"}"
                            "}"
                        )
                    },
                    {
                        "role": "user",
                        "content": f"Create a mimic recipe for the '{dish_name}' that you see in the image using that exact JSON structure."
                    }
                ],
                max_tokens=1000,
                timeout=60
            )
            mimic_raw = mimic_response.choices[0].message.content.strip()
            mimic_recipe = json.loads(mimic_raw)
        except Exception as e:
            print("🔥 Error during mimic recipe:", e)
            mimic_recipe = {
                "title": "Mimic Version",
                "ingredients": [],
                "instructions": [],
                "servings": 0,
                "prepTime": "",
                "cookTime": "",
                "nutrition": {}
            }

        # ✅ Final response
        return jsonify({
            "title": dish_name,
            "description": description,
            "healthyRecipe": healthy_recipe,
            "mimicRecipe": mimic_recipe,
            "imageUrl": image_url
        })

    except Exception as e:
        print("🔥 Global error during analysis:", str(e))
        return jsonify({"error": str(e)}), 500

@app.route("/cloudinary-signature", methods=["POST"])
def cloudinary_signature():
    data = request.get_json()
    public_id = data.get("public_id")
    folder = data.get("folder")
    timestamp = data.get("timestamp") or str(int(time.time()))
    overwrite = str(data.get("overwrite", True)).lower()

    if not public_id or not folder:
        return jsonify({"error": "Missing public_id or folder"}), 400

    # ✅ Include 'folder' in the signature
    params_to_sign = {
        "folder": folder,
        "overwrite": overwrite,
        "public_id": public_id,
        "timestamp": timestamp
    }

    to_sign = "&".join(f"{k}={v}" for k, v in sorted(params_to_sign.items()))
    print(f"🧾 TO_SIGN: {to_sign}")

    signature = hmac.new(
        os.environ["CLOUDINARY_API_SECRET"].encode("utf-8"),
        to_sign.encode("utf-8"),
        hashlib.sha1
    ).hexdigest()

    print(f"🔐 SERVER SIGNATURE: {signature}")

    return jsonify({
        "signature": signature,
        "timestamp": timestamp,
        "api_key": os.environ["CLOUDINARY_API_KEY"],
        "cloud_name": os.environ["CLOUDINARY_CLOUD_NAME"]
    })

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

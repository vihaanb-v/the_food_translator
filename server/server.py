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
import uuid

load_dotenv(dotenv_path="secrets.env")

app = Flask(__name__)

openai.api_key = os.getenv("OPENAI_API_KEY")
CLOUDINARY_CLOUD_NAME = os.getenv("CLOUDINARY_CLOUD_NAME")
CLOUDINARY_API_KEY = os.getenv("CLOUDINARY_API_KEY")
CLOUDINARY_API_SECRET = os.getenv("CLOUDINARY_API_SECRET")

# ✅ Cloudinary config
cloudinary.config(
    cloud_name=CLOUDINARY_CLOUD_NAME,
    api_key=CLOUDINARY_API_KEY,
    api_secret=CLOUDINARY_API_SECRET,
)

@app.route("/analyze", methods=["POST"])
def analyze():
    try:
        data = request.get_json(force=True)
        image_b64 = data.get("image")
        user_caption = data.get("caption", "").strip()

        if not image_b64:
            return jsonify({"error": "No image provided"}), 400

        # Decode image
        try:
            image_bytes = base64.b64decode(image_b64)
        except Exception:
            return jsonify({"error": "Invalid base64 image"}), 400

        # Save image to temp file
        temp_filename = "temp.jpg"
        with open(temp_filename, "wb") as f:
            f.write(image_bytes)

        # Upload to Cloudinary
        unique_id = f"dish_{uuid.uuid4().hex[:10]}"

        try:
            upload_result = cloudinary.uploader.upload(
                temp_filename,
                folder="disypher_uploads",  # You can name the folder anything
                public_id=unique_id,
                use_filename=True,
                overwrite=False
            )
            image_url = upload_result.get("secure_url") + "?f_auto,q_auto"
        except Exception as e:
            return jsonify({"error": "Cloudinary upload failed", "details": str(e)}), 500
        finally:
            if os.path.exists(temp_filename):
                os.remove(temp_filename)

        if not image_url:
            return jsonify({"error": "Image upload did not return a URL."}), 500

        # -------- DISH NAME GENERATION --------
        try:
            system_prompt = (
                "You are a culinary expert. Return ONLY a JSON object like: "
                "{\"title\": \"Chicken Alfredo\"}. No explanation. No markdown. Just clean JSON."
            )

            user_message = [
                {"type": "text", "text": "What is the name of this dish? If not a food fish return the unknown JSON. Return only JSON."},
                {"type": "image_url", "image_url": {"url": image_url}},
            ]
            if user_caption:
                user_message.insert(0, {"type": "text", "text": f"User also says: {user_caption}"})

            name_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": user_message}
                ],
                max_tokens=100,
                timeout=30
            )

            raw_json = name_response.choices[0].message.content.strip()
            print(f"Raw GPT JSON response: {raw_json}")

            try:
                parsed = json.loads(raw_json)
                dish_name = parsed.get("title") or parsed.get("dish_name") or ""
            except json.JSONDecodeError:
                dish_name = ""

            dish_name = dish_name.strip()

            # Validate the dish name
            if (
                not dish_name
                or not isinstance(dish_name, str)
                or dish_name.lower() in {"dish", "food", "unknown", "none"}
                or not re.search(r"[A-Za-z]{3,}", dish_name)
            ):
                dish_name = "Unknown Dish"

        except Exception as e:
            print("🔥 Error during dish name generation:", e)
            dish_name = "Unknown Dish"

        print(f"✅ Parsed dish name: '{dish_name}'")

        # --- EARLY EXIT: Unknown Dish ---
        if dish_name == "Unknown Dish":
            print("⚠️ GPT could not identify dish. Returning early with trigger for Flutter popup.")
            return jsonify({"trigger": "show_unknown_popup"}), 200  # ✅ FLUTTER WILL DETECT THIS

    # -------- DESCRIPTION GENERATION --------
        try:
            prompt = f"Describe the dish '{dish_name}' in two clean and precise yet descriptive sentences."
            if user_caption:
                prompt += f" User also described it as: \"{user_caption}\""

            desc_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": (
                        "You are a culinary expert. Write an accurate description describing the dish you see in the image."
                        "Mention ingredients, flavors, and textures."
                    )},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=300,
                timeout=30
            )
            description = desc_response.choices[0].message.content.strip()
        except Exception as e:
            print("🔥 Error during description:", e)
            description = "No description available."

        # -------- HEALTHY RECIPE --------
        try:
            healthy_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": (
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
                    )},
                    {"role": "user", "content": f"Give a healthier recipe for the '{dish_name}' using that JSON structure."}
                ],
                max_tokens=1000,
                timeout=60
            )
            healthy_recipe = json.loads(healthy_response.choices[0].message.content.strip())
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

        # -------- MIMIC RECIPE --------
        try:
            mimic_response = openai.chat.completions.create(
                model="gpt-4o",
                messages=[
                    {"role": "system", "content": (
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
                    )},
                    {"role": "user", "content": f"Create a mimic recipe for the '{dish_name}' using that JSON structure."}
                ],
                max_tokens=1000,
                timeout=60
            )
            mimic_recipe = json.loads(mimic_response.choices[0].message.content.strip())
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

        # ✅ Final JSON return
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
def generate_signature():
    try:
        data = request.get_json(force=True)

        # Required keys from Flutter
        required_keys = ["public_id", "folder", "timestamp", "upload_preset"]
        missing_keys = [key for key in required_keys if key not in data]
        if missing_keys:
            return jsonify({
                "error": f"Missing required keys: {', '.join(missing_keys)}"
            }), 400

        # Extract in the same order Flutter sends them
        public_id = str(data["public_id"])
        folder = str(data["folder"])
        timestamp = str(data["timestamp"])
        upload_preset = str(data["upload_preset"])

        # Manual ordering to match Flutter and Cloudinary
        to_sign = (
            f"folder={folder}&"
            f"public_id={public_id}&"
            f"timestamp={timestamp}&"
            f"upload_preset={upload_preset}"
        )

        to_sign_str = to_sign + CLOUDINARY_API_SECRET
        signature = hashlib.sha1(to_sign_str.encode("utf-8")).hexdigest()

        return jsonify({
            "api_key": CLOUDINARY_API_KEY,
            "cloud_name": CLOUDINARY_CLOUD_NAME,
            "folder": folder,
            "public_id": public_id,
            "signature": signature,
            "timestamp": timestamp,
            "upload_preset": upload_preset
        })

    except Exception as e:
        print(f"[❌ CLOUDINARY SIGNATURE ERROR] {e}")
        return jsonify({
            "error": "Failed to generate signature",
            "details": str(e)
        }), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

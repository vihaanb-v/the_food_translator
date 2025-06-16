import os
import base64
import re
import json
from dotenv import load_dotenv
from flask import Flask, request, jsonify
import openai
import cloudinary
import cloudinary.uploader

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
        data = request.json
        image_b64 = data.get("image")
        if not image_b64:
            return jsonify({"error": "No image provided"}), 400

        # Decode and save image
        image_bytes = base64.b64decode(image_b64)
        with open("temp.jpg", "wb") as f:
            f.write(image_bytes)

        # Upload to Cloudinary
        upload_result = cloudinary.uploader.upload("temp.jpg")
        image_url = upload_result.get("secure_url")
        os.remove("temp.jpg")

        if not image_url:
            return jsonify({"error": "Cloudinary upload failed"}), 500

        # --- Dish name ---
        name_response = openai.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a culinary expert. Return ONLY a JSON object like: "
                        "{\"dish_name\": \"Chicken Alfredo\"}. No intro, no explanation, just the JSON."
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
            max_tokens=100
        )

        raw_json = name_response.choices[0].message.content.strip()
        print(f"Raw GPT JSON response: {raw_json}")

        try:
            parsed = json.loads(raw_json)
            dish_name = parsed.get("dish_name", "").strip()
        except json.JSONDecodeError:
            dish_name = ""

        match = re.search(r"([A-Z][a-zA-Z\s\-']{2,50})", dish_name)
        if match:
            dish_name = match.group(0).strip()

        if not dish_name or dish_name.lower() in {"dish", "food", "unknown"}:
            dish_name = "Unknown Dish"

        print(f"Parsed dish name: '{dish_name}'")

        # --- Dish description ---
        desc_response = openai.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a culinary expert. Write an accurate description describing the dish you see in the image."
                        "Mention ingredients, flavors, and textures."
                    )
                },
                {
                    "role": "user",
                    "content": f"Describe the dish '{dish_name}' in two clean and precise yet descriptive sentences."
                }
            ],
            max_tokens=300
        )

        description = desc_response.choices[0].message.content.strip()
        if not description:
            description = "No description available."

        # --- Healthier Recipe ---
        healthy_response = openai.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a professional nutritionist and chef. Create a healthier version of a dish."
                        " Return only detailed recipe instructions. Include ingredients with quantities, serving size,"
                        " prep and cook time, and full nutritional breakdown (calories, protein, carbs, fats)."
                    )
                },
                {
                    "role": "user",
                    "content": f"Create a healthier version of the dish '{dish_name}' without compromising too much on flavor."
                }
            ],
            max_tokens=1000
        )

        healthy_recipe = healthy_response.choices[0].message.content.strip()

        # --- Mimic Recipe ---
        mimic_response = openai.chat.completions.create(
            model="gpt-4o",
            messages=[
                {
                    "role": "system",
                    "content": (
                        "You are a culinary expert recreating a dish based on its appearance and name. Return a thorough recipe "
                        "that closely mimics the original dish visually and flavor-wise. Include ingredients with quantities, "
                        "serving size, prep and cook time, and step-by-step instructions with nutritional breakdown."
                    )
                },
                {
                    "role": "user",
                    "content": f"Based on its name and typical appearance, write a full recipe for '{dish_name}' that closely mimics the original."
                }
            ],
            max_tokens=1000
        )

        mimic_recipe = mimic_response.choices[0].message.content.strip()

        # --- Final JSON ---
        return jsonify({
            "title": dish_name,
            "description": description,
            "healthyRecipe": healthy_recipe,
            "mimicRecipe": mimic_recipe
        })

    except Exception as e:
        print("Error during analysis:", str(e))
        return jsonify({"error": str(e)}), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)

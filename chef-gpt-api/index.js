import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import OpenAI from 'openai';

dotenv.config();
const app = express();
const port = process.env.PORT || 3000;

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY });

app.use(cors());
app.use(express.json());

app.post('/gpt-chef', async (req, res) => {
  const { messages, context } = req.body;

  try {
    const fullMessages = [
      {
        role: 'system',
        content:
          `You are ChefGPT, a charming culinary expert who helps users improve recipes, suggest substitutions, and make things healthier or tastier.\n` +
          `Context: ${context || 'No dish context provided.'}`,
      },
      ...messages,
    ];

    const chat = await openai.chat.completions.create({
      model: 'gpt-4o',
      messages: fullMessages,
    });

    const reply = chat.choices[0].message.content;
    res.json({ reply });
  } catch (err) {
    console.error('GPT error:', err.message);
    res.status(500).json({ error: 'GPT failed' });
  }
});

app.listen(port, () => {
  console.log(`🔥 ChefGPT API running on http://localhost:${port}`);
});

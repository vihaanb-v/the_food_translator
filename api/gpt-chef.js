import express from 'express';
import cors from 'cors';
import dotenv from 'dotenv';
import OpenAI from 'openai';

// Load environment variables
dotenv.config();

const app = express();
app.use(cors());
app.use(express.json());

const openai = new OpenAI({ apiKey: process.env.OPENAI_API_KEY_CHATBOT });

app.post('/api/gpt-chef', async (req, res) => {
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
    res.status(200).json({ reply });
  } catch (err) {
    console.error('GPT error:', err.message);
    res.status(500).json({ error: 'GPT failed' });
  }
});

// 👇 This is crucial for Vercel – no `app.listen()`!
export default app;

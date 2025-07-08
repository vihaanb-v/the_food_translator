import { OpenAI } from 'openai';

const openai = new OpenAI({
  apiKey: process.env.OPENAI_API_KEY_CHATBOT,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

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
}

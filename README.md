🌐 What’s Needed for Others to Run It

    Frontend (HTML/JS)

        Anyone can open your index.html in a browser.

        The gradient theme, chat UI, and speech synthesis (Speak button / Auto‑speak) will work immediately because those use built‑in browser features.

    Backend (API server)

        The chat interface expects a backend at http://localhost:3000/api/chat.

        That means anyone who wants to use it must also run your Node/Express backend locally, or you need to host it somewhere accessible (Heroku, Vercel, your own server, etc.).

    Model Runtime (Ollama or other)

        The backend needs to connect to a model runtime (like Ollama).

        Anyone who wants to run it must install Ollama (or whatever runtime you’ve chosen) and pull the models you reference (deepseek-r1, gemma3, qwen3, etc.).

    Browser Support

        Speech synthesis works best in Chrome, Edge, and Safari.

        Firefox has partial support, but some voices may not load correctly.

        No extra installs are needed for speech — it’s built into the browser.

🔑 Options for Sharing

    Local use: Anyone with Node + Ollama can run the backend and open the HTML file.

    Hosted use: If you deploy the backend to a server and serve the HTML from a public URL, then anyone can just visit the site — no local setup required.

    Speech: Works automatically for anyone with a modern browser, once the page is loaded.

full backend script:

nano setup_backend.sh


#!/bin/bash
# Capsule Backend Setup Script with Cleanup
# Creates backend project structure, installs dependencies, and scaffolds files

# Create project folder
mkdir -p backend/routes backend/uploads
cd backend || exit

# Initialize npm project
npm init -y

# Install dependencies
npm install express cors dotenv multer node-fetch ssh2
npm install --save-dev nodemon

# Create .env file
cat > .env << 'EOF'
# Local Ollama API
OLLAMA_URL=http://localhost:11434

# Future external APIs (placeholders)
SEARCH_API_KEY=your-search-key-here
SSH_API_KEY=your-ssh-key-here
VISION_API_KEY=your-vision-key-here

# Server port
PORT=3000
EOF

# Create package.json with scripts
cat > package.json << 'EOF'
{
  "name": "capsule-backend",
  "version": "1.0.0",
  "description": "Capsule backend for Ollama + tools",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "cleanup": "node cleanup.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.0",
    "express": "^4.19.2",
    "multer": "^1.4.5",
    "node-fetch": "^3.3.2",
    "ssh2": "^1.15.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  }
}
EOF

# Create server.js
cat > server.js << 'EOF'
import express from "express";
import cors from "cors";
import dotenv from "dotenv";

import chatRouter from "./routes/chat.js";
import searchRouter from "./routes/search.js";
import sshRouter from "./routes/ssh.js";
import visionRouter from "./routes/vision.js";

dotenv.config();
const app = express();

app.use(cors());
app.use(express.json());

// Routes
app.use("/api/chat", chatRouter);
app.use("/api/search", searchRouter);
app.use("/api/ssh", sshRouter);
app.use("/api/vision", visionRouter);

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Capsule backend running on http://localhost:${PORT}`));
EOF

# Create routes/chat.js
cat > routes/chat.js << 'EOF'
import express from "express";
import fetch from "node-fetch";

const router = express.Router();

router.post("/", async (req, res) => {
  const { model, prompt, stream } = req.body;
  try {
    const response = await fetch(`${process.env.OLLAMA_URL}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ model, prompt, stream })
    });
    response.body.pipe(res);
  } catch (err) {
    res.status(500).json({ error: "Ollama backend not reachable" });
  }
});

export default router;
EOF

# Create routes/search.js
cat > routes/search.js << 'EOF'
import express from "express";

const router = express.Router();

// Placeholder search route
router.get("/", async (req, res) => {
  const { q } = req.query;
  // Future: integrate Bing/Google API using SEARCH_API_KEY
  res.json({ results: [`Search results for: ${q}`] });
});

export default router;
EOF

# Create routes/ssh.js
cat > routes/ssh.js << 'EOF'
import express from "express";
import { Client } from "ssh2";

const router = express.Router();

router.post("/", (req, res) => {
  const { host, username, password, command } = req.body;
  const conn = new Client();

  conn.on("ready", () => {
    conn.exec(command, (err, stream) => {
      if (err) return res.status(500).json({ error: err.message });
      let output = "";
      stream.on("data", (data) => (output += data.toString()));
      stream.on("close", () => {
        conn.end();
        res.json({ output });
      });
    });
  }).connect({ host, username, password });
});

export default router;
EOF

# Create routes/vision.js with cleanup
cat > routes/vision.js << 'EOF'
import express from "express";
import multer from "multer";
import fetch from "node-fetch";
import fs from "fs";

const router = express.Router();
const upload = multer({ dest: "uploads/" });

router.post("/", upload.single("file"), async (req, res) => {
  const { prompt } = req.body;
  const filePath = req.file.path;

  try {
    const response = await fetch(`${process.env.OLLAMA_URL}/api/generate`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        model: "llama3.2-vision:11b",
        prompt: `${prompt}\n[Image: ${filePath}]`,
        stream: false
      })
    });
    const data = await response.json();

    // Cleanup file immediately after use
    fs.unlink(filePath, (err) => {
      if (err) console.error("Cleanup failed:", err);
    });

    res.json({ reply: data.response });
  } catch (err) {
    // Cleanup even if error
    fs.unlink(filePath, () => {});
    res.status(500).json({ error: "Vision model not reachable" });
  }
});

export default router;
EOF

# Create cleanup.js for scheduled purges
cat > cleanup.js << 'EOF'
import fs from "fs";
import path from "path";

const uploadsDir = path.join(process.cwd(), "uploads");

fs.readdir(uploadsDir, (err, files) => {
  if (err) return console.error("Error reading uploads:", err);

  const now = Date.now();
  files.forEach(file => {
    const filePath = path.join(uploadsDir, file);
    fs.stat(filePath, (err, stats) => {
      if (err) return;
      const ageHours = (now - stats.mtimeMs) / (1000 * 60 * 60);
      if (ageHours > 24) {
        fs.unlink(filePath, (err) => {
          if (err) console.error("Failed to delete:", filePath);
          else console.log("Deleted old file:", filePath);
        });
      }
    });
  });
});
EOF

echo "✅ Backend scaffold complete. Run with: npm run dev"
echo "🧹 To cleanup old uploads manually: npm run cleanup"
echo "⏰ To schedule cleanup daily, add cron: 0 2 * * * cd $(pwd) && npm run cleanup"


chmod +x setup_backend.sh


./setup_backend.sh


cd backend
npm run dev


Test cleanup manually:

npm run cleanup


crontab -e


0 2 * * * cd /path/to/backend && npm run cleanup


full frontend html:

<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Capsule Chat Interface</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <style>
    body {
      background: linear-gradient(135deg, #1a2a6c, #b21f1f, #1a2a6c);
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 20px;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    .chat-container {
      width: 100%;
      max-width: 900px;
      height: 90vh;
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      box-shadow: 0 15px 35px rgba(0,0,0,0.25);
      display: flex;
      flex-direction: column;
      overflow: hidden;
      border: 1px solid rgba(255,255,255,0.2);
      position: relative;
    }
    .chat-header {
      background: rgba(0,0,0,0.3);
      padding: 20px;
      text-align: center;
      border-bottom: 1px solid rgba(255,255,255,0.1);
      position: relative;
    }
    .chat-header h1 { color: white; font-size: 1.8rem; margin-bottom: 5px; }
    .chat-header p { color: rgba(255,255,255,0.7); font-size: 0.9rem; margin-bottom: 10px; }
    #model-select {
      padding: 8px 12px;
      border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.2);
      background: rgba(255,255,255,0.15);
      color: white;
      outline: none;
      font-size: 0.95rem;
      width: 250px;
    }
    .chat-messages {
      flex: 1;
      padding: 20px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 15px;
    }
    .message {
      max-width: 80%;
      padding: 15px;
      border-radius: 18px;
      line-height: 1.5;
      animation: fadeIn 0.3s ease-out;
    }
    @keyframes fadeIn { from {opacity:0;transform:translateY(10px);} to {opacity:1;transform:translateY(0);} }
    .user-message {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      color: white;
      align-self: flex-end;
      border-bottom-right-radius: 5px;
    }
    .ai-message {
      background: rgba(255,255,255,0.15);
      color: white;
      align-self: flex-start;
      border-bottom-left-radius: 5px;
    }
    .message-header {
      display: flex;
      align-items: center;
      margin-bottom: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      opacity: 0.9;
    }
    .message-header i {
      margin-right: 5px;
      font-size: 0.75rem;
    }
    .message-content {
      font-size: 1rem;
      line-height: 1.6;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .message-content h1, .message-content h2, .message-content h3, .message-content h4, .message-content h5, .message-content h6 {
      margin: 10px 0 5px 0;
      color: rgba(255,255,255,0.9);
    }
    .message-content p {
      margin: 8px 0;
    }
    .message-content ul, .message-content ol {
      margin: 8px 0;
      padding-left: 20px;
    }
    .message-content li {
      margin: 4px 0;
    }
    .message-content code {
      background: rgba(0,0,0,0.3);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'Courier New', monospace;
      font-size: 0.9em;
    }
    .message-content pre {
      background: rgba(0,0,0,0.3);
      padding: 12px;
      border-radius: 8px;
      overflow-x: auto;
      margin: 10px 0;
    }
    .message-content pre code {
      background: none;
      padding: 0;
    }
    .message-content blockquote {
      border-left: 3px solid rgba(255,255,255,0.5);
      padding-left: 12px;
      margin: 10px 0;
      color: rgba(255,255,255,0.8);
    }
    .message-content table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    .message-content th, .message-content td {
      border: 1px solid rgba(255,255,255,0.3);
      padding: 8px;
      text-align: left;
    }
    .message-content th {
      background: rgba(0,0,0,0.2);
    }
    .typing-indicator {
      display: none;
      background: rgba(255,255,255,0.15);
      color: white;
      align-self: flex-start;
      padding: 15px;
      border-radius: 18px;
      border-bottom-left-radius: 5px;
      margin: 0 20px 10px 20px;
    }
    .typing-indicator span {
      height: 10px; width: 10px; float: left; margin: 0 2px;
      background-color: rgba(255,255,255,0.7);
      border-radius: 50%; opacity: 0.4;
      animation: typing 1s infinite;
    }
    .typing-indicator span:nth-of-type(2){animation-delay:0.2s;}
    .typing-indicator span:nth-of-type(3){animation-delay:0.4s;}
    @keyframes typing {0%{transform:translateY(0);}50%{transform:translateY(-5px);}100%{transform:translateY(0);}}
    .chat-input {
      display: flex;
      padding: 20px;
      background: rgba(0,0,0,0.2);
      border-top: 1px solid rgba(255,255,255,0.1);
      align-items: center;
    }
    .chat-input input[type="text"] {
      flex: 1; padding: 15px 20px; border: none; border-radius: 30px;
      background: rgba(255,255,255,0.15); color: white; font-size: 1rem;
      outline: none; transition: all 0.3s ease;
    }
    .chat-input input[type="text"]:focus {
      background: rgba(255,255,255,0.25);
      box-shadow: 0 0 0 2px rgba(78,84,200,0.5);
    }
    .chat-input input::placeholder { color: rgba(255,255,255,0.6); }
    .chat-input button {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      border: none; color: white; width: 50px; height: 50px;
      border-radius: 50%; margin-left: 15px; cursor: pointer;
      transition: all 0.3s ease; display: flex; justify-content: center; align-items: center;
      font-size: 1.2rem;
    }
    .chat-input button:hover { transform: scale(1.05); box-shadow: 0 0 15px rgba(78,84,200,0.5); }
    .chat-input button:active { transform: scale(0.95); }
    #upload-button,#tools-button,#speak-button {
      width:40px;height:40px;margin-right:10px;font-size:1rem;
      display:flex;justify-content:center;align-items:center;
    }
    .speak-active {
      background: linear-gradient(135deg,#b21f1f,#ff5e62) !important;
      box-shadow: 0 0 10px rgba(178,31,31,0.7) !important;
    }
    .tools-menu, .chat-history-menu {
      display:none;position:absolute;bottom:90px;left:20px;
      background:rgba(0,0,0,0.6);padding:15px;border-radius:12px;
      box-shadow:0 5px 15px rgba(0,0,0,0.3);color:white;font-size:0.9rem;
      min-width:220px;z-index:10;
    }
    .chat-history-menu {
      bottom: 140px;
      width: 250px;
    }
    .tools-menu h4,.chat-history-menu h4{margin-bottom:8px;font-weight:600;color:rgba(255,255,255,0.85);}
    .tools-menu label,.chat-history-menu button,.chat-history-menu input{display:block;margin-bottom:8px;cursor:pointer;width: 100%;}
    .chat-history-menu button {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      border: none;
      color: white;
      padding: 10px;
      border-radius: 8px;
      font-size: 0.9rem;
      transition: all 0.3s ease;
    }
    .chat-history-menu button:hover {
      transform: scale(1.02);
      box-shadow: 0 0 10px rgba(78,84,200,0.5);
    }
    .chat-history-menu input {
      padding: 8px;
      border-radius: 8px;
      background: rgba(255,255,255,0.15);
      border: 1px solid rgba(255,255,255,0.2);
      color: white;
      margin-bottom: 10px;
    }
    .chat-history-menu input::placeholder {
      color: rgba(255,255,255,0.6);
    }
    .message img,.message video{max-width:100%;border-radius:12px;margin-top:10px;box-shadow:0 5px 15px rgba(0,0,0,0.3);}
    .message video{max-height:300px;}
    .history-button {
      position: absolute;
      top: 20px;
      right: 20px;
      background: rgba(255,255,255,0.15);
      border: none;
      color: white;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      justify-content: center;
      align-items: center;
      font-size: 1rem;
      transition: all 0.3s ease;
    }
    .history-button:hover {
      background: rgba(255,255,255,0.25);
      transform: scale(1.05);
    }
    .saved-chats-list {
      max-height: 150px;
      overflow-y: auto;
      margin-top: 10px;
    }
    .saved-chat-item {
      padding: 8px;
      border-radius: 5px;
      margin-bottom: 5px;
      background: rgba(255,255,255,0.1);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .saved-chat-item:hover {
      background: rgba(255,255,255,0.2);
    }
  </style>
</head>
<body>
  <div class="chat-container">
    <div class="chat-header">
      <h1><i class="fas fa-robot"></i> AI Assistant</h1>
      <p>Powered by Capsule Backend</p>
      <select id="model-select">
        <option value="gemma3:27b-cloud">gemma3:27b-cloud</option>
        <option value="qwen3-vl:235b-cloud">qwen3-vl:235b-cloud</option>
        <option value="qwen3-vl:8b">qwen3-vl:8b</option>
        <option value="glm-4.6:cloud">glm-4.6:cloud</option>
        <option value="deepseek-ocr:3b">deepseek-ocr:3b</option>
        <option value="minimax-m2:cloud">minimax-m2:cloud</option>
        <option value="cogito-2.1:671b-cloud">cogito-2.1:671b-cloud</option>
        <option value="kimi-k2-thinking:cloud">kimi-k2-thinking:cloud</option>
        <option value="alibayram/hunyuan:4b">alibayram/hunyuan:4b</option>
        <option value="deepseek-r1:1.5b">deepseek-r1:1.5b</option>
        <option value="mistral-large-3:675b-cloud">mistral-large-3:675b-cloud</option>
        <option value="qwen3:8b">qwen3:8b</option>
        <option value="gemma3:4b">gemma3:4b</option>
        <option value="nemotron-mini:4b">nemotron-mini:4b</option>
        <option value="deepseek-r1:8b">deepseek-r1:8b</option>
        <option value="ministral-3:8b">ministral-3:8b</option>
        <option value="second_constantine/gpt-oss-u:20b">second_constantine/gpt-oss-u:20b</option>
        <option value="gpt-oss:20b">gpt-oss:20b</option>
        <option value="llama3.2-vision:11b">llama3.2-vision:11b</option>
        <option value="gemini-3-pro-preview:latest">gemini-3-pro-preview:latest</option>
        <option value="deepseek-v3.1:671b-cloud">deepseek-v3.1:671b-cloud</option>
        <option value="gpt-oss:120b-cloud">gpt-oss:120b-cloud</option>
        <option value="qwen3-coder:480b-cloud">qwen3-coder:480b-cloud</option>
      </select>
      <button class="history-button" id="history-button"><i class="fas fa-history"></i></button>
    </div>
    <div class="chat-messages" id="chat-messages"></div>
    <div class="typing-indicator" id="typing-indicator"><span></span><span></span><span></span></div>
    <div class="chat-input">
      <button id="upload-button"><i class="fas fa-plus"></i></button>
      <button id="tools-button"><i class="fas fa-cogs"></i></button>
      <button id="speak-button"><i class="fas fa-volume-up"></i></button>
      <input type="file" id="file-upload" accept="image/*,video/*" style="display:none">
      <input type="text" id="user-input" placeholder="Type your message here...">
      <button id="send-button"><i class="fas fa-paper-plane"></i></button>
    </div>
    <div id="tools-menu" class="tools-menu">
      <h4>Tool options</h4>
      <label><input type="checkbox" id="use-search-web"> Use Web Search</label>
      <label><input type="checkbox" id="use-terminal-ssh"> Use Terminal/SSH</label>
      <label><input type="checkbox" id="use-vision"> Use Vision (if model supports)</label>
      <label><input type="checkbox" id="auto-speak"> Auto Speak Responses</label>
    </div>
    <div id="chat-history-menu" class="chat-history-menu">
      <h4>Chat History</h4>
      <input type="text" id="chat-name" placeholder="Enter chat name...">
      <button id="save-chat-button"><i class="fas fa-save"></i> Save Current Chat</button>
      <button id="load-chat-button"><i class="fas fa-folder-open"></i> Load Chat from File</button>
      <div class="saved-chats-list" id="saved-chats-list">
        <div class="saved-chat-item">No saved chats yet</div>
      </div>
    </div>
    <input type="file" id="load-chat-file" accept=".json" style="display:none">
  </div>

  <script>
    document.addEventListener('DOMContentLoaded', function() {
      const chatMessages = document.getElementById('chat-messages');
      const userInput = document.getElementById('user-input');
      const sendButton = document.getElementById('send-button');
      const typingIndicator = document.getElementById('typing-indicator');
      const uploadButton = document.getElementById('upload-button');
      const fileUpload = document.getElementById('file-upload');
      const toolsButton = document.getElementById('tools-button');
      const toolsMenu = document.getElementById('tools-menu');
      const modelSelect = document.getElementById('model-select');
      const speakButton = document.getElementById('speak-button');
      const historyButton = document.getElementById('history-button');
      const chatHistoryMenu = document.getElementById('chat-history-menu');
      const saveChatButton = document.getElementById('save-chat-button');
      const loadChatButton = document.getElementById('load-chat-button');
      const chatNameInput = document.getElementById('chat-name');
      const savedChatsList = document.getElementById('saved-chats-list');
      const loadChatFile = document.getElementById('load-chat-file');
      const synth = window.speechSynthesis;
      let isSpeaking = false;
      
      // Configure marked.js for safe rendering
      marked.setOptions({
        breaks: true, // Convert '\n' in text into <br>
        gfm: true, // Enable GitHub Flavored Markdown
        sanitize: false, // Don't sanitize HTML (we trust our backend)
        highlight: function(code, lang) {
          // Simple syntax highlighting fallback
          return `<code class="language-${lang}">${code}</code>`;
        }
      });
      
      // Store chat messages for saving
      let chatHistory = [];

      function addMessage(text, isUser) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', isUser ? 'user-message' : 'ai-message');
        
        // Create message header with icon and name
        const messageHeader = document.createElement('div');
        messageHeader.classList.add('message-header');
        
        if (isUser) {
          messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
        } else {
          // Get a simplified model name for display
          const modelName = getModelDisplayName(modelSelect.value);
          messageHeader.innerHTML = `<i class="fas fa-robot"></i> ${modelName}`;
        }
        
        // Create message content
        const messageContent = document.createElement('div');
        messageContent.classList.add('message-content');
        
        if (isUser) {
          // For user messages, use plain text (no Markdown rendering)
          messageContent.textContent = text;
        } else {
          // For AI messages, render Markdown
          messageContent.innerHTML = marked.parse(text);
        }
        
        // Append header and content to message
        messageDiv.appendChild(messageHeader);
        messageDiv.appendChild(messageContent);
        
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // Add to chat history for saving
        chatHistory.push({
          text: text,
          isUser: isUser,
          model: isUser ? null : modelSelect.value, // Store model only for AI messages
          timestamp: new Date().toISOString()
        });
      }

      // Helper function to get a simplified display name for models
      function getModelDisplayName(fullModelName) {
        const modelMap = {
          'gemma3:27b-cloud': 'Gemma3 27B Cloud',
          'qwen3-vl:235b-cloud': 'Qwen3 VL 235B Cloud',
          'qwen3-vl:8b': 'Qwen3 VL 8B',
          'glm-4.6:cloud': 'GLM 4.6 Cloud',
          'deepseek-ocr:3b': 'DeepSeek OCR 3B',
          'minimax-m2:cloud': 'Minimax M2 Cloud',
          'cogito-2.1:671b-cloud': 'Cogito 2.1 671B Cloud',
          'kimi-k2-thinking:cloud': 'Kimi K2 Thinking Cloud',
          'alibayram/hunyuan:4b': 'Hunyuan 4B',
          'deepseek-r1:1.5b': 'DeepSeek R1 1.5B',
          'mistral-large-3:675b-cloud': 'Mistral Large 675B',
          'qwen3:8b': 'Qwen3 8B',
          'gemma3:4b': 'Gemma3 4B',
          'nemotron-mini:4b': 'Nemotron Mini 4B',
          'deepseek-r1:8b': 'DeepSeek R1 8B',
          'ministral-3:8b': 'Ministral 3 8B',
          'second_constantine/gpt-oss-u:20b': 'GPT-OSS 20B',
          'gpt-oss:20b': 'GPT-OSS 20B',
          'llama3.2-vision:11b': 'Llama 3.2 Vision 11B',
          'gemini-3-pro-preview:latest': 'Gemini 3 Pro',
          'deepseek-v3.1:671b-cloud': 'DeepSeek V3.1 671B',
          'gpt-oss:120b-cloud': 'GPT-OSS 120B',
          'qwen3-coder:480b-cloud': 'Qwen3 Coder 480B'
        };
        
        return modelMap[fullModelName] || fullModelName.split('/').pop().split(':')[0];
      }

      function addMediaMessage(file) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', 'user-message');
        
        // Create message header with icon and name
        const messageHeader = document.createElement('div');
        messageHeader.classList.add('message-header');
        messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
        messageDiv.appendChild(messageHeader);
        
        const fileName = document.createElement('p');
        fileName.textContent = `Uploaded: ${file.name}`;
        messageDiv.appendChild(fileName);

        if (file.type.startsWith('image/')) {
          const img = document.createElement('img');
          img.src = URL.createObjectURL(file);
          messageDiv.appendChild(img);
        } else if (file.type.startsWith('video/')) {
          const video = document.createElement('video');
          video.src = URL.createObjectURL(file);
          video.controls = true;
          messageDiv.appendChild(video);
        }

        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // Add to chat history for saving
        chatHistory.push({
          media: {
            name: file.name,
            type: file.type,
            // Note: Can't directly store the file, but we can note it was uploaded
          },
          isUser: true,
          timestamp: new Date().toISOString()
        });
      }

      async function getAIResponseStream(userMessage) {
        const model = modelSelect.value;
        const payload = { model, prompt: userMessage, stream: true };

        try {
          const response = await fetch("http://localhost:3000/api/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          if (!response.ok || !response.body) throw new Error('No stream available');

          const reader = response.body.getReader();
          const decoder = new TextDecoder('utf-8');
          let fullText = '';
          let buffer = '';

          typingIndicator.style.display = 'block';

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop();
            for (const line of lines) {
              if (!line.trim()) continue;
              try {
                const json = JSON.parse(line);
                if (json.response) fullText += json.response;
              } catch {}
            }
          }

          typingIndicator.style.display = 'none';
          return fullText || "(No response)";
        } catch (err) {
          typingIndicator.style.display = 'none';
          return "(Backend not reachable)";
        }
      }

      async function sendMessage() {
        const message = userInput.value.trim();
        if (!message) return;
        addMessage(message, true);
        userInput.value = '';

        const useSearchWeb = document.getElementById('use-search-web').checked;
        const useTerminalSSH = document.getElementById('use-terminal-ssh').checked;
        const useVision = document.getElementById('use-vision').checked;

        typingIndicator.style.display = 'block';

        let preface = '';
        const flags = [];
        if (useSearchWeb) flags.push('WebSearch');
        if (useTerminalSSH) flags.push('Terminal/SSH');
        if (useVision) flags.push('Vision');
        if (flags.length) preface = `[Tools: ${flags.join(', ')}] `;

        const aiResponse = await getAIResponseStream(message);
        typingIndicator.style.display = 'none';
        addMessage(preface + aiResponse, false);

        // Auto speak if enabled
        if (document.getElementById('auto-speak').checked) {
          speakText(preface + aiResponse);
        }
      }

      function speakText(text) {
        if (!synth || isSpeaking) return;
        
        // Stop any ongoing speech
        synth.cancel();
        
        // Strip markdown for speech (remove formatting)
        const plainText = text.replace(/[#*`_\[\]\(\)]/g, '');
        
        const utterance = new SpeechSynthesisUtterance(plainText);
        utterance.rate = 1;
        utterance.pitch = 1;
        utterance.volume = 1;
        
        // Update UI when speech starts and ends
        utterance.onstart = function() {
          isSpeaking = true;
          speakButton.classList.add('speak-active');
          speakButton.innerHTML = '<i class="fas fa-stop"></i>';
        };
        
        utterance.onend = function() {
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        };
        
        utterance.onerror = function() {
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        };
        
        synth.speak(utterance);
      }

      function stopSpeaking() {
        if (synth && isSpeaking) {
          synth.cancel();
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        }
      }
      
      // Save chat function
      function saveChat() {
        const chatName = chatNameInput.value.trim() || `Chat_${new Date().toISOString().slice(0,19).replace(/:/g,'-')}`;
        const chatData = {
          name: chatName,
          messages: chatHistory,
          model: modelSelect.value,
          timestamp: new Date().toISOString()
        };
        
        // Save to localStorage for quick access
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChats.push(chatData);
        localStorage.setItem('savedChats', JSON.stringify(savedChats));
        
        // Also download as JSON file
        const dataStr = JSON.stringify(chatData, null, 2);
        const dataBlob = new Blob([dataStr], {type: 'application/json'});
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${chatName}.json`;
        link.click();
        URL.revokeObjectURL(url);
        
        // Update saved chats list
        updateSavedChatsList();
        alert(`Chat saved as "${chatName}"`);
      }
      
      // Load chat function
      function loadChat(chatData) {
        if (!chatData || !chatData.messages) {
          alert('Invalid chat file');
          return;
        }
        
        // Clear current chat
        chatMessages.innerHTML = '';
        chatHistory = [];
        
        // Load messages
        chatData.messages.forEach(msg => {
          const messageDiv = document.createElement('div');
          messageDiv.classList.add('message', msg.isUser ? 'user-message' : 'ai-message');
          
          // Create message header with icon and name
          const messageHeader = document.createElement('div');
          messageHeader.classList.add('message-header');
          
          if (msg.isUser) {
            messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
            
            // Check if it's a media message
            if (msg.media) {
              const fileName = document.createElement('p');
              fileName.textContent = `Uploaded: ${msg.media.name}`;
              messageDiv.appendChild(messageHeader);
              messageDiv.appendChild(fileName);
              messageDiv.innerHTML += '<p><i>Note: Media files cannot be restored from saved chats</i></p>';
            } else {
              const messageContent = document.createElement('div');
              messageContent.classList.add('message-content');
              messageContent.textContent = msg.text;
              messageDiv.appendChild(messageHeader);
              messageDiv.appendChild(messageContent);
            }
          } else {
            // Use the stored model name or current model for AI messages
            const modelName = msg.model ? getModelDisplayName(msg.model) : getModelDisplayName(modelSelect.value);
            messageHeader.innerHTML = `<i class="fas fa-robot"></i> ${modelName}`;
            
            const messageContent = document.createElement('div');
            messageContent.classList.add('message-content');
            messageContent.innerHTML = marked.parse(msg.text);
            messageDiv.appendChild(messageHeader);
            messageDiv.appendChild(messageContent);
          }
          
          chatMessages.appendChild(messageDiv);
          
          // Add to chat history
          chatHistory.push(msg);
        });
        
        // Restore model if available
        if (chatData.model) {
          modelSelect.value = chatData.model;
        }
        
        chatMessages.scrollTop = chatMessages.scrollHeight;
        alert(`Chat "${chatData.name}" loaded successfully`);
      }
      
      // Update saved chats list
      function updateSavedChatsList() {
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChatsList.innerHTML = '';
        
        if (savedChats.length === 0) {
          savedChatsList.innerHTML = '<div class="saved-chat-item">No saved chats yet</div>';
          return;
        }
        
        savedChats.forEach((chat, index) => {
          const chatItem = document.createElement('div');
          chatItem.classList.add('saved-chat-item');
          chatItem.innerHTML = `
            <strong>${chat.name}</strong><br>
            <small>${new Date(chat.timestamp).toLocaleString()}</small>
          `;
          chatItem.addEventListener('click', () => {
            if (confirm(`Load chat "${chat.name}"? This will replace the current chat.`)) {
              loadChat(chat);
              chatHistoryMenu.style.display = 'none';
            }
          });
          savedChatsList.appendChild(chatItem);
        });
      }

      // Speak button: toggle speak/stop
      speakButton.addEventListener('click', () => {
        if (isSpeaking) {
          stopSpeaking();
        } else {
          const aiMessages = document.querySelectorAll('.ai-message');
          if (aiMessages.length > 0) {
            const lastMessage = aiMessages[aiMessages.length - 1];
            // Get the raw text from the message content (before Markdown rendering)
            const lastMessageIndex = chatHistory.length - 1;
            if (lastMessageIndex >= 0 && !chatHistory[lastMessageIndex].isUser) {
              const text = chatHistory[lastMessageIndex].text;
              if (text.trim() !== '') {
                speakText(text);
              }
            }
          }
        }
      });

      sendButton.addEventListener('click', sendMessage);
      userInput.addEventListener('keypress', e => { if (e.key === 'Enter') sendMessage(); });
      uploadButton.addEventListener('click', () => fileUpload.click());
      fileUpload.addEventListener('change', e => { const file = e.target.files[0]; if (file) addMediaMessage(file); });
      toolsButton.addEventListener('click', () => { toolsMenu.style.display = toolsMenu.style.display === 'block' ? 'none' : 'block'; });
      document.addEventListener('click', e => { 
        if (!toolsMenu.contains(e.target) && !toolsButton.contains(e.target)) toolsMenu.style.display = 'none'; 
      });
      
      // Chat history menu functionality
      historyButton.addEventListener('click', () => { 
        chatHistoryMenu.style.display = chatHistoryMenu.style.display === 'block' ? 'none' : 'block'; 
        updateSavedChatsList();
      });
      document.addEventListener('click', e => { 
        if (!chatHistoryMenu.contains(e.target) && !historyButton.contains(e.target)) chatHistoryMenu.style.display = 'none'; 
      });
      
      saveChatButton.addEventListener('click', saveChat);
      loadChatButton.addEventListener('click', () => loadChatFile.click());
      
      loadChatFile.addEventListener('change', e => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = function(e) {
            try {
              const chatData = JSON.parse(e.target.result);
              loadChat(chatData);
            } catch (err) {
              alert('Error loading chat file: ' + err.message);
            }
          };
          reader.readAsText(file);
        }
      });
      
      // Initialize saved chats list
      updateSavedChatsList();
    });
  </script>
</body>
</html>


install script:


```bash
#!/bin/bash

# Capsule Chat Full Installation Script
# This script installs Ollama, downloads models, sets up the backend, and deploys the frontend

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Capsule Chat Installation Script ===${NC}"
echo -e "${YELLOW}This script will install everything needed to run Capsule Chat${NC}"
echo ""

# Function to log messages
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    warn "Running as root. It's recommended to run this script as a regular user."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Detect OS
OS=$(uname -s)
ARCH=$(uname -m)

log "Detected OS: $OS, Architecture: $ARCH"

# Install Ollama
install_ollama() {
    log "Installing Ollama..."
    
    if command -v ollama &> /dev/null; then
        log "Ollama is already installed"
        return 0
    fi
    
    case $OS in
        "Linux")
            if [ "$ARCH" = "x86_64" ]; then
                curl -fsSL https://ollama.ai/install.sh | sh
            else
                warn "Non-x86_64 architecture detected. Please install Ollama manually from https://ollama.ai"
                return 1
            fi
            ;;
        "Darwin")
            if command -v brew &> /dev/null; then
                brew install ollama
            else
                # Install Ollama via direct download for macOS
                curl -fsSL https://ollama.ai/install.sh | sh
            fi
            ;;
        *)
            error "Unsupported OS: $OS"
            warn "Please install Ollama manually from https://ollama.ai"
            return 1
            ;;
    esac
    
    # Start Ollama service
    log "Starting Ollama service..."
    case $OS in
        "Linux")
            sudo systemctl enable ollama
            sudo systemctl start ollama
            ;;
        "Darwin")
            brew services start ollama
            ;;
    esac
    
    # Wait for Ollama to start
    sleep 5
}

# Download models
download_models() {
    log "Downloading AI models (this may take a while depending on your internet connection)..."
    
    local models=(
        "deepseek-r1:1.5b"
        "qwen2.5:3b"
        "gemma2:2b"
        "llama3.2:3b"
        "mistral:7b"
        "llama3.2-vision:11b"
    )
    
    for model in "${models[@]}"; do
        log "Downloading model: $model"
        if ! ollama pull "$model"; then
            warn "Failed to download model: $model. Continuing with others..."
        fi
    done
}

# Setup backend
setup_backend() {
    log "Setting up backend..."
    
    # Create project structure
    mkdir -p capsule-chat/backend/routes capsule-chat/backend/uploads
    cd capsule-chat/backend || exit 1
    
    # Initialize npm project
    npm init -y
    
    # Install dependencies
    log "Installing backend dependencies..."
    npm install express cors dotenv multer node-fetch ssh2
    npm install --save-dev nodemon
    
    # Create environment file
    cat > .env << 'EOF'
# Ollama API URL
OLLAMA_URL=http://localhost:11434

# Server configuration
PORT=3000
HOST=localhost

# Optional API keys (for future enhancements)
# SEARCH_API_KEY=your_search_api_key_here
# SSH_HOST=your_ssh_host
# SSH_USER=your_ssh_user
# SSH_PASS=your_ssh_password
EOF

    # Update package.json with scripts
    cat > package.json << 'EOF'
{
  "name": "capsule-chat-backend",
  "version": "1.0.0",
  "description": "Backend for Capsule Chat Interface",
  "main": "server.js",
  "type": "module",
  "scripts": {
    "start": "node server.js",
    "dev": "nodemon server.js",
    "cleanup": "node cleanup.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.0",
    "express": "^4.19.2",
    "multer": "^1.4.5",
    "node-fetch": "^3.3.2",
    "ssh2": "^1.15.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.0"
  }
}
EOF

    # Create server.js
    cat > server.js << 'EOF'
import express from "express";
import cors from "cors";
import dotenv from "dotenv";
import path from "path";
import { fileURLToPath } from "url";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.static(path.join(__dirname, '../frontend')));

// Basic health check
app.get("/api/health", (req, res) => {
    res.json({ status: "OK", message: "Capsule Backend is running" });
});

// Chat endpoint (simplified - connects to Ollama)
app.post("/api/chat", async (req, res) => {
    const { model, prompt, stream = true } = req.body;
    
    try {
        const response = await fetch(`${process.env.OLLAMA_URL}/api/generate`, {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model, prompt, stream })
        });
        
        if (!response.ok) {
            throw new Error(`Ollama API error: ${response.status}`);
        }
        
        if (stream) {
            // Stream the response
            res.setHeader('Content-Type', 'application/json');
            response.body.pipe(res);
        } else {
            const data = await response.json();
            res.json(data);
        }
    } catch (error) {
        console.error("Chat error:", error);
        res.status(500).json({ 
            error: "Failed to connect to AI model", 
            message: error.message,
            suggestion: "Make sure Ollama is running and the model is downloaded"
        });
    }
});

// Search endpoint (placeholder)
app.get("/api/search", async (req, res) => {
    const { q } = req.query;
    res.json({ 
        results: [`Search functionality for "${q}" would be implemented here`],
        note: "This is a placeholder endpoint. Integrate with a search API for full functionality."
    });
});

// SSH endpoint (placeholder with safety warning)
app.post("/api/ssh", (req, res) => {
    res.json({ 
        warning: "SSH functionality is disabled by default for security reasons",
        note: "Enable and configure SSH credentials in production with proper security measures"
    });
});

// Vision endpoint (placeholder)
app.post("/api/vision", (req, res) => {
    res.json({ 
        note: "Vision functionality requires a vision-capable model like llama3.2-vision",
        suggestion: "Use the llama3.2-vision:11b model for image processing"
    });
});

// Serve frontend
app.get("/", (req, res) => {
    res.sendFile(path.join(__dirname, '../frontend/index.html'));
});

const PORT = process.env.PORT || 3000;
const HOST = process.env.HOST || 'localhost';

app.listen(PORT, HOST, () => {
    console.log(`🚀 Capsule Backend running on http://${HOST}:${PORT}`);
    console.log(`💬 Chat API available at http://${HOST}:${PORT}/api/chat`);
    console.log(`🔍 Make sure Ollama is running at ${process.env.OLLAMA_URL}`);
});
EOF

    # Create cleanup script
    cat > cleanup.js << 'EOF'
import fs from "fs";
import path from "path";

const uploadsDir = path.join(process.cwd(), "uploads");

if (fs.existsSync(uploadsDir)) {
    fs.readdir(uploadsDir, (err, files) => {
        if (err) {
            console.error("Error reading uploads directory:", err);
            return;
        }
        
        let deletedCount = 0;
        files.forEach(file => {
            const filePath = path.join(uploadsDir, file);
            try {
                fs.unlinkSync(filePath);
                deletedCount++;
                console.log("Deleted:", filePath);
            } catch (unlinkErr) {
                console.error("Failed to delete:", filePath, unlinkErr);
            }
        });
        
        console.log(`Cleanup completed. Deleted ${deletedCount} files.`);
    });
} else {
    console.log("Uploads directory does not exist. Nothing to clean up.");
}
EOF

    cd ../..
}

# Setup frontend
setup_frontend() {
    log "Setting up frontend..."
    
    mkdir -p capsule-chat/frontend
    cd capsule-chat/frontend || exit 1
    
    # Create the HTML file
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Capsule Chat Interface</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <script src="https://cdn.jsdelivr.net/npm/marked/marked.min.js"></script>
  <style>
    body {
      background: linear-gradient(135deg, #1a2a6c, #b21f1f, #1a2a6c);
      min-height: 100vh;
      display: flex;
      justify-content: center;
      align-items: center;
      padding: 20px;
      font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
    }
    .chat-container {
      width: 100%;
      max-width: 900px;
      height: 90vh;
      background: rgba(255,255,255,0.1);
      backdrop-filter: blur(10px);
      border-radius: 20px;
      box-shadow: 0 15px 35px rgba(0,0,0,0.25);
      display: flex;
      flex-direction: column;
      overflow: hidden;
      border: 1px solid rgba(255,255,255,0.2);
      position: relative;
    }
    .chat-header {
      background: rgba(0,0,0,0.3);
      padding: 20px;
      text-align: center;
      border-bottom: 1px solid rgba(255,255,255,0.1);
      position: relative;
    }
    .chat-header h1 { color: white; font-size: 1.8rem; margin-bottom: 5px; }
    .chat-header p { color: rgba(255,255,255,0.7); font-size: 0.9rem; margin-bottom: 10px; }
    #model-select {
      padding: 8px 12px;
      border-radius: 12px;
      border: 1px solid rgba(255,255,255,0.2);
      background: rgba(255,255,255,0.15);
      color: white;
      outline: none;
      font-size: 0.95rem;
      width: 250px;
    }
    .chat-messages {
      flex: 1;
      padding: 20px;
      overflow-y: auto;
      display: flex;
      flex-direction: column;
      gap: 15px;
    }
    .message {
      max-width: 80%;
      padding: 15px;
      border-radius: 18px;
      line-height: 1.5;
      animation: fadeIn 0.3s ease-out;
    }
    @keyframes fadeIn { from {opacity:0;transform:translateY(10px);} to {opacity:1;transform:translateY(0);} }
    .user-message {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      color: white;
      align-self: flex-end;
      border-bottom-right-radius: 5px;
    }
    .ai-message {
      background: rgba(255,255,255,0.15);
      color: white;
      align-self: flex-start;
      border-bottom-left-radius: 5px;
    }
    .message-header {
      display: flex;
      align-items: center;
      margin-bottom: 8px;
      font-size: 0.85rem;
      font-weight: 600;
      opacity: 0.9;
    }
    .message-header i {
      margin-right: 5px;
      font-size: 0.75rem;
    }
    .message-content {
      font-size: 1rem;
      line-height: 1.6;
      white-space: pre-wrap;
      word-wrap: break-word;
    }
    .message-content h1, .message-content h2, .message-content h3, .message-content h4, .message-content h5, .message-content h6 {
      margin: 10px 0 5px 0;
      color: rgba(255,255,255,0.9);
    }
    .message-content p {
      margin: 8px 0;
    }
    .message-content ul, .message-content ol {
      margin: 8px 0;
      padding-left: 20px;
    }
    .message-content li {
      margin: 4px 0;
    }
    .message-content code {
      background: rgba(0,0,0,0.3);
      padding: 2px 6px;
      border-radius: 4px;
      font-family: 'Courier New', monospace;
      font-size: 0.9em;
    }
    .message-content pre {
      background: rgba(0,0,0,0.3);
      padding: 12px;
      border-radius: 8px;
      overflow-x: auto;
      margin: 10px 0;
    }
    .message-content pre code {
      background: none;
      padding: 0;
    }
    .message-content blockquote {
      border-left: 3px solid rgba(255,255,255,0.5);
      padding-left: 12px;
      margin: 10px 0;
      color: rgba(255,255,255,0.8);
    }
    .message-content table {
      width: 100%;
      border-collapse: collapse;
      margin: 10px 0;
    }
    .message-content th, .message-content td {
      border: 1px solid rgba(255,255,255,0.3);
      padding: 8px;
      text-align: left;
    }
    .message-content th {
      background: rgba(0,0,0,0.2);
    }
    .typing-indicator {
      display: none;
      background: rgba(255,255,255,0.15);
      color: white;
      align-self: flex-start;
      padding: 15px;
      border-radius: 18px;
      border-bottom-left-radius: 5px;
      margin: 0 20px 10px 20px;
    }
    .typing-indicator span {
      height: 10px; width: 10px; float: left; margin: 0 2px;
      background-color: rgba(255,255,255,0.7);
      border-radius: 50%; opacity: 0.4;
      animation: typing 1s infinite;
    }
    .typing-indicator span:nth-of-type(2){animation-delay:0.2s;}
    .typing-indicator span:nth-of-type(3){animation-delay:0.4s;}
    @keyframes typing {0%{transform:translateY(0);}50%{transform:translateY(-5px);}100%{transform:translateY(0);}}
    .chat-input {
      display: flex;
      padding: 20px;
      background: rgba(0,0,0,0.2);
      border-top: 1px solid rgba(255,255,255,0.1);
      align-items: center;
    }
    .chat-input input[type="text"] {
      flex: 1; padding: 15px 20px; border: none; border-radius: 30px;
      background: rgba(255,255,255,0.15); color: white; font-size: 1rem;
      outline: none; transition: all 0.3s ease;
    }
    .chat-input input[type="text"]:focus {
      background: rgba(255,255,255,0.25);
      box-shadow: 0 0 0 2px rgba(78,84,200,0.5);
    }
    .chat-input input::placeholder { color: rgba(255,255,255,0.6); }
    .chat-input button {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      border: none; color: white; width: 50px; height: 50px;
      border-radius: 50%; margin-left: 15px; cursor: pointer;
      transition: all 0.3s ease; display: flex; justify-content: center; align-items: center;
      font-size: 1.2rem;
    }
    .chat-input button:hover { transform: scale(1.05); box-shadow: 0 0 15px rgba(78,84,200,0.5); }
    .chat-input button:active { transform: scale(0.95); }
    #upload-button,#tools-button,#speak-button {
      width:40px;height:40px;margin-right:10px;font-size:1rem;
      display:flex;justify-content:center;align-items:center;
    }
    .speak-active {
      background: linear-gradient(135deg,#b21f1f,#ff5e62) !important;
      box-shadow: 0 0 10px rgba(178,31,31,0.7) !important;
    }
    .tools-menu, .chat-history-menu {
      display:none;position:absolute;bottom:90px;left:20px;
      background:rgba(0,0,0,0.6);padding:15px;border-radius:12px;
      box-shadow:0 5px 15px rgba(0,0,0,0.3);color:white;font-size:0.9rem;
      min-width:220px;z-index:10;
    }
    .chat-history-menu {
      bottom: 140px;
      width: 250px;
    }
    .tools-menu h4,.chat-history-menu h4{margin-bottom:8px;font-weight:600;color:rgba(255,255,255,0.85);}
    .tools-menu label,.chat-history-menu button,.chat-history-menu input{display:block;margin-bottom:8px;cursor:pointer;width: 100%;}
    .chat-history-menu button {
      background: linear-gradient(135deg,#4e54c8,#8f94fb);
      border: none;
      color: white;
      padding: 10px;
      border-radius: 8px;
      font-size: 0.9rem;
      transition: all 0.3s ease;
    }
    .chat-history-menu button:hover {
      transform: scale(1.02);
      box-shadow: 0 0 10px rgba(78,84,200,0.5);
    }
    .chat-history-menu input {
      padding: 8px;
      border-radius: 8px;
      background: rgba(255,255,255,0.15);
      border: 1px solid rgba(255,255,255,0.2);
      color: white;
      margin-bottom: 10px;
    }
    .chat-history-menu input::placeholder {
      color: rgba(255,255,255,0.6);
    }
    .message img,.message video{max-width:100%;border-radius:12px;margin-top:10px;box-shadow:0 5px 15px rgba(0,0,0,0.3);}
    .message video{max-height:300px;}
    .history-button {
      position: absolute;
      top: 20px;
      right: 20px;
      background: rgba(255,255,255,0.15);
      border: none;
      color: white;
      width: 40px;
      height: 40px;
      border-radius: 50%;
      cursor: pointer;
      display: flex;
      justify-content: center;
      align-items: center;
      font-size: 1rem;
      transition: all 0.3s ease;
    }
    .history-button:hover {
      background: rgba(255,255,255,0.25);
      transform: scale(1.05);
    }
    .saved-chats-list {
      max-height: 150px;
      overflow-y: auto;
      margin-top: 10px;
    }
    .saved-chat-item {
      padding: 8px;
      border-radius: 5px;
      margin-bottom: 5px;
      background: rgba(255,255,255,0.1);
      cursor: pointer;
      transition: all 0.2s ease;
    }
    .saved-chat-item:hover {
      background: rgba(255,255,255,0.2);
    }
  </style>
</head>
<body>
  <div class="chat-container">
    <div class="chat-header">
      <h1><i class="fas fa-robot"></i> AI Assistant</h1>
      <p>Powered by Capsule Backend</p>
      <select id="model-select">
        <option value="gemma3:27b-cloud">gemma3:27b-cloud</option>
        <option value="qwen3-vl:235b-cloud">qwen3-vl:235b-cloud</option>
        <option value="qwen3-vl:8b">qwen3-vl:8b</option>
        <option value="glm-4.6:cloud">glm-4.6:cloud</option>
        <option value="deepseek-ocr:3b">deepseek-ocr:3b</option>
        <option value="minimax-m2:cloud">minimax-m2:cloud</option>
        <option value="cogito-2.1:671b-cloud">cogito-2.1:671b-cloud</option>
        <option value="kimi-k2-thinking:cloud">kimi-k2-thinking:cloud</option>
        <option value="alibayram/hunyuan:4b">alibayram/hunyuan:4b</option>
        <option value="deepseek-r1:1.5b">deepseek-r1:1.5b</option>
        <option value="mistral-large-3:675b-cloud">mistral-large-3:675b-cloud</option>
        <option value="qwen3:8b">qwen3:8b</option>
        <option value="gemma3:4b">gemma3:4b</option>
        <option value="nemotron-mini:4b">nemotron-mini:4b</option>
        <option value="deepseek-r1:8b">deepseek-r1:8b</option>
        <option value="ministral-3:8b">ministral-3:8b</option>
        <option value="second_constantine/gpt-oss-u:20b">second_constantine/gpt-oss-u:20b</option>
        <option value="gpt-oss:20b">gpt-oss:20b</option>
        <option value="llama3.2-vision:11b">llama3.2-vision:11b</option>
        <option value="gemini-3-pro-preview:latest">gemini-3-pro-preview:latest</option>
        <option value="deepseek-v3.1:671b-cloud">deepseek-v3.1:671b-cloud</option>
        <option value="gpt-oss:120b-cloud">gpt-oss:120b-cloud</option>
        <option value="qwen3-coder:480b-cloud">qwen3-coder:480b-cloud</option>
      </select>
      <button class="history-button" id="history-button"><i class="fas fa-history"></i></button>
    </div>
    <div class="chat-messages" id="chat-messages"></div>
    <div class="typing-indicator" id="typing-indicator"><span></span><span></span><span></span></div>
    <div class="chat-input">
      <button id="upload-button"><i class="fas fa-plus"></i></button>
      <button id="tools-button"><i class="fas fa-cogs"></i></button>
      <button id="speak-button"><i class="fas fa-volume-up"></i></button>
      <input type="file" id="file-upload" accept="image/*,video/*" style="display:none">
      <input type="text" id="user-input" placeholder="Type your message here...">
      <button id="send-button"><i class="fas fa-paper-plane"></i></button>
    </div>
    <div id="tools-menu" class="tools-menu">
      <h4>Tool options</h4>
      <label><input type="checkbox" id="use-search-web"> Use Web Search</label>
      <label><input type="checkbox" id="use-terminal-ssh"> Use Terminal/SSH</label>
      <label><input type="checkbox" id="use-vision"> Use Vision (if model supports)</label>
      <label><input type="checkbox" id="auto-speak"> Auto Speak Responses</label>
    </div>
    <div id="chat-history-menu" class="chat-history-menu">
      <h4>Chat History</h4>
      <input type="text" id="chat-name" placeholder="Enter chat name...">
      <button id="save-chat-button"><i class="fas fa-save"></i> Save Current Chat</button>
      <button id="load-chat-button"><i class="fas fa-folder-open"></i> Load Chat from File</button>
      <div class="saved-chats-list" id="saved-chats-list">
        <div class="saved-chat-item">No saved chats yet</div>
      </div>
    </div>
    <input type="file" id="load-chat-file" accept=".json" style="display:none">
  </div>

  <script>
    document.addEventListener('DOMContentLoaded', function() {
      const chatMessages = document.getElementById('chat-messages');
      const userInput = document.getElementById('user-input');
      const sendButton = document.getElementById('send-button');
      const typingIndicator = document.getElementById('typing-indicator');
      const uploadButton = document.getElementById('upload-button');
      const fileUpload = document.getElementById('file-upload');
      const toolsButton = document.getElementById('tools-button');
      const toolsMenu = document.getElementById('tools-menu');
      const modelSelect = document.getElementById('model-select');
      const speakButton = document.getElementById('speak-button');
      const historyButton = document.getElementById('history-button');
      const chatHistoryMenu = document.getElementById('chat-history-menu');
      const saveChatButton = document.getElementById('save-chat-button');
      const loadChatButton = document.getElementById('load-chat-button');
      const chatNameInput = document.getElementById('chat-name');
      const savedChatsList = document.getElementById('saved-chats-list');
      const loadChatFile = document.getElementById('load-chat-file');
      const synth = window.speechSynthesis;
      let isSpeaking = false;
      
      // Configure marked.js for safe rendering
      marked.setOptions({
        breaks: true, // Convert '\n' in text into <br>
        gfm: true, // Enable GitHub Flavored Markdown
        sanitize: false, // Don't sanitize HTML (we trust our backend)
        highlight: function(code, lang) {
          // Simple syntax highlighting fallback
          return `<code class="language-${lang}">${code}</code>`;
        }
      });
      
      // Store chat messages for saving
      let chatHistory = [];

      function addMessage(text, isUser) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', isUser ? 'user-message' : 'ai-message');
        
        // Create message header with icon and name
        const messageHeader = document.createElement('div');
        messageHeader.classList.add('message-header');
        
        if (isUser) {
          messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
        } else {
          // Get a simplified model name for display
          const modelName = getModelDisplayName(modelSelect.value);
          messageHeader.innerHTML = `<i class="fas fa-robot"></i> ${modelName}`;
        }
        
        // Create message content
        const messageContent = document.createElement('div');
        messageContent.classList.add('message-content');
        
        if (isUser) {
          // For user messages, use plain text (no Markdown rendering)
          messageContent.textContent = text;
        } else {
          // For AI messages, render Markdown
          messageContent.innerHTML = marked.parse(text);
        }
        
        // Append header and content to message
        messageDiv.appendChild(messageHeader);
        messageDiv.appendChild(messageContent);
        
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // Add to chat history for saving
        chatHistory.push({
          text: text,
          isUser: isUser,
          model: isUser ? null : modelSelect.value, // Store model only for AI messages
          timestamp: new Date().toISOString()
        });
      }

      // Helper function to get a simplified display name for models
      function getModelDisplayName(fullModelName) {
        const modelMap = {
          'gemma3:27b-cloud': 'Gemma3 27B Cloud',
          'qwen3-vl:235b-cloud': 'Qwen3 VL 235B Cloud',
          'qwen3-vl:8b': 'Qwen3 VL 8B',
          'glm-4.6:cloud': 'GLM 4.6 Cloud',
          'deepseek-ocr:3b': 'DeepSeek OCR 3B',
          'minimax-m2:cloud': 'Minimax M2 Cloud',
          'cogito-2.1:671b-cloud': 'Cogito 2.1 671B Cloud',
          'kimi-k2-thinking:cloud': 'Kimi K2 Thinking Cloud',
          'alibayram/hunyuan:4b': 'Hunyuan 4B',
          'deepseek-r1:1.5b': 'DeepSeek R1 1.5B',
          'mistral-large-3:675b-cloud': 'Mistral Large 675B',
          'qwen3:8b': 'Qwen3 8B',
          'gemma3:4b': 'Gemma3 4B',
          'nemotron-mini:4b': 'Nemotron Mini 4B',
          'deepseek-r1:8b': 'DeepSeek R1 8B',
          'ministral-3:8b': 'Ministral 3 8B',
          'second_constantine/gpt-oss-u:20b': 'GPT-OSS 20B',
          'gpt-oss:20b': 'GPT-OSS 20B',
          'llama3.2-vision:11b': 'Llama 3.2 Vision 11B',
          'gemini-3-pro-preview:latest': 'Gemini 3 Pro',
          'deepseek-v3.1:671b-cloud': 'DeepSeek V3.1 671B',
          'gpt-oss:120b-cloud': 'GPT-OSS 120B',
          'qwen3-coder:480b-cloud': 'Qwen3 Coder 480B'
        };
        
        return modelMap[fullModelName] || fullModelName.split('/').pop().split(':')[0];
      }

      function addMediaMessage(file) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', 'user-message');
        
        // Create message header with icon and name
        const messageHeader = document.createElement('div');
        messageHeader.classList.add('message-header');
        messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
        messageDiv.appendChild(messageHeader);
        
        const fileName = document.createElement('p');
        fileName.textContent = `Uploaded: ${file.name}`;
        messageDiv.appendChild(fileName);

        if (file.type.startsWith('image/')) {
          const img = document.createElement('img');
          img.src = URL.createObjectURL(file);
          messageDiv.appendChild(img);
        } else if (file.type.startsWith('video/')) {
          const video = document.createElement('video');
          video.src = URL.createObjectURL(file);
          video.controls = true;
          messageDiv.appendChild(video);
        }

        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        // Add to chat history for saving
        chatHistory.push({
          media: {
            name: file.name,
            type: file.type,
            // Note: Can't directly store the file, but we can note it was uploaded
          },
          isUser: true,
          timestamp: new Date().toISOString()
        });
      }

      async function getAIResponseStream(userMessage) {
        const model = modelSelect.value;
        const payload = { model, prompt: userMessage, stream: true };

        try {
          const response = await fetch("http://localhost:3000/api/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify(payload)
          });

          if (!response.ok || !response.body) throw new Error('No stream available');

          const reader = response.body.getReader();
          const decoder = new TextDecoder('utf-8');
          let fullText = '';
          let buffer = '';

          typingIndicator.style.display = 'block';

          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            buffer += decoder.decode(value, { stream: true });
            const lines = buffer.split('\n');
            buffer = lines.pop();
            for (const line of lines) {
              if (!line.trim()) continue;
              try {
                const json = JSON.parse(line);
                if (json.response) fullText += json.response;
              } catch {}
            }
          }

          typingIndicator.style.display = 'none';
          return fullText || "(No response)";
        } catch (err) {
          typingIndicator.style.display = 'none';
          return "(Backend not reachable)";
        }
      }

      async function sendMessage() {
        const message = userInput.value.trim();
        if (!message) return;
        addMessage(message, true);
        userInput.value = '';

        const useSearchWeb = document.getElementById('use-search-web').checked;
        const useTerminalSSH = document.getElementById('use-terminal-ssh').checked;
        const useVision = document.getElementById('use-vision').checked;

        typingIndicator.style.display = 'block';

        let preface = '';
        const flags = [];
        if (useSearchWeb) flags.push('WebSearch');
        if (useTerminalSSH) flags.push('Terminal/SSH');
        if (useVision) flags.push('Vision');
        if (flags.length) preface = `[Tools: ${flags.join(', ')}] `;

        const aiResponse = await getAIResponseStream(message);
        typingIndicator.style.display = 'none';
        addMessage(preface + aiResponse, false);

        // Auto speak if enabled
        if (document.getElementById('auto-speak').checked) {
          speakText(preface + aiResponse);
        }
      }

      function speakText(text) {
        if (!synth || isSpeaking) return;
        
        // Stop any ongoing speech
        synth.cancel();
        
        // Strip markdown for speech (remove formatting)
        const plainText = text.replace(/[#*`_\[\]\(\)]/g, '');
        
        const utterance = new SpeechSynthesisUtterance(plainText);
        utterance.rate = 1;
        utterance.pitch = 1;
        utterance.volume = 1;
        
        // Update UI when speech starts and ends
        utterance.onstart = function() {
          isSpeaking = true;
          speakButton.classList.add('speak-active');
          speakButton.innerHTML = '<i class="fas fa-stop"></i>';
        };
        
        utterance.onend = function() {
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        };
        
        utterance.onerror = function() {
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        };
        
        synth.speak(utterance);
      }

      function stopSpeaking() {
        if (synth && isSpeaking) {
          synth.cancel();
          isSpeaking = false;
          speakButton.classList.remove('speak-active');
          speakButton.innerHTML = '<i class="fas fa-volume-up"></i>';
        }
      }
      
      // Save chat function
      function saveChat() {
        const chatName = chatNameInput.value.trim() || `Chat_${new Date().toISOString().slice(0,19).replace(/:/g,'-')}`;
        const chatData = {
          name: chatName,
          messages: chatHistory,
          model: modelSelect.value,
          timestamp: new Date().toISOString()
        };
        
        // Save to localStorage for quick access
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChats.push(chatData);
        localStorage.setItem('savedChats', JSON.stringify(savedChats));
        
        // Also download as JSON file
        const dataStr = JSON.stringify(chatData, null, 2);
        const dataBlob = new Blob([dataStr], {type: 'application/json'});
        const url = URL.createObjectURL(dataBlob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `${chatName}.json`;
        link.click();
        URL.revokeObjectURL(url);
        
        // Update saved chats list
        updateSavedChatsList();
        alert(`Chat saved as "${chatName}"`);
      }
      
      // Load chat function
      function loadChat(chatData) {
        if (!chatData || !chatData.messages) {
          alert('Invalid chat file');
          return;
        }
        
        // Clear current chat
        chatMessages.innerHTML = '';
        chatHistory = [];
        
        // Load messages
        chatData.messages.forEach(msg => {
          const messageDiv = document.createElement('div');
          messageDiv.classList.add('message', msg.isUser ? 'user-message' : 'ai-message');
          
          // Create message header with icon and name
          const messageHeader = document.createElement('div');
          messageHeader.classList.add('message-header');
          
          if (msg.isUser) {
            messageHeader.innerHTML = '<i class="fas fa-user"></i> User';
            
            // Check if it's a media message
            if (msg.media) {
              const fileName = document.createElement('p');
              fileName.textContent = `Uploaded: ${msg.media.name}`;
              messageDiv.appendChild(messageHeader);
              messageDiv.appendChild(fileName);
              messageDiv.innerHTML += '<p><i>Note: Media files cannot be restored from saved chats</i></p>';
            } else {
              const messageContent = document.createElement('div');
              messageContent.classList.add('message-content');
              messageContent.textContent = msg.text;
              messageDiv.appendChild(messageHeader);
              messageDiv.appendChild(messageContent);
            }
          } else {
            // Use the stored model name or current model for AI messages
            const modelName = msg.model ? getModelDisplayName(msg.model) : getModelDisplayName(modelSelect.value);
            messageHeader.innerHTML = `<i class="fas fa-robot"></i> ${modelName}`;
            
            const messageContent = document.createElement('div');
            messageContent.classList.add('message-content');
            messageContent.innerHTML = marked.parse(msg.text);
            messageDiv.appendChild(messageHeader);
            messageDiv.appendChild(messageContent);
          }
          
          chatMessages.appendChild(messageDiv);
          
          // Add to chat history
          chatHistory.push(msg);
        });
        
        // Restore model if available
        if (chatData.model) {
          modelSelect.value = chatData.model;
        }
        
        chatMessages.scrollTop = chatMessages.scrollHeight;
        alert(`Chat "${chatData.name}" loaded successfully`);
      }
      
      // Update saved chats list
      function updateSavedChatsList() {
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChatsList.innerHTML = '';
        
        if (savedChats.length === 0) {
          savedChatsList.innerHTML = '<div class="saved-chat-item">No saved chats yet</div>';
          return;
        }
        
        savedChats.forEach((chat, index) => {
          const chatItem = document.createElement('div');
          chatItem.classList.add('saved-chat-item');
          chatItem.innerHTML = `
            <strong>${chat.name}</strong><br>
            <small>${new Date(chat.timestamp).toLocaleString()}</small>
          `;
          chatItem.addEventListener('click', () => {
            if (confirm(`Load chat "${chat.name}"? This will replace the current chat.`)) {
              loadChat(chat);
              chatHistoryMenu.style.display = 'none';
            }
          });
          savedChatsList.appendChild(chatItem);
        });
      }

      // Speak button: toggle speak/stop
      speakButton.addEventListener('click', () => {
        if (isSpeaking) {
          stopSpeaking();
        } else {
          const aiMessages = document.querySelectorAll('.ai-message');
          if (aiMessages.length > 0) {
            const lastMessage = aiMessages[aiMessages.length - 1];
            // Get the raw text from the message content (before Markdown rendering)
            const lastMessageIndex = chatHistory.length - 1;
            if (lastMessageIndex >= 0 && !chatHistory[lastMessageIndex].isUser) {
              const text = chatHistory[lastMessageIndex].text;
              if (text.trim() !== '') {
                speakText(text);
              }
            }
          }
        }
      });

      sendButton.addEventListener('click', sendMessage);
      userInput.addEventListener('keypress', e => { if (e.key === 'Enter') sendMessage(); });
      uploadButton.addEventListener('click', () => fileUpload.click());
      fileUpload.addEventListener('change', e => { const file = e.target.files[0]; if (file) addMediaMessage(file); });
      toolsButton.addEventListener('click', () => { toolsMenu.style.display = toolsMenu.style.display === 'block' ? 'none' : 'block'; });
      document.addEventListener('click', e => { 
        if (!toolsMenu.contains(e.target) && !toolsButton.contains(e.target)) toolsMenu.style.display = 'none'; 
      });
      
      // Chat history menu functionality
      historyButton.addEventListener('click', () => { 
        chatHistoryMenu.style.display = chatHistoryMenu.style.display === 'block' ? 'none' : 'block'; 
        updateSavedChatsList();
      });
      document.addEventListener('click', e => { 
        if (!chatHistoryMenu.contains(e.target) && !historyButton.contains(e.target)) chatHistoryMenu.style.display = 'none'; 
      });
      
      saveChatButton.addEventListener('click', saveChat);
      loadChatButton.addEventListener('click', () => loadChatFile.click());
      
      loadChatFile.addEventListener('change', e => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = function(e) {
            try {
              const chatData = JSON.parse(e.target.result);
              loadChat(chatData);
            } catch (err) {
              alert('Error loading chat file: ' + err.message);
            }
          };
          reader.readAsText(file);
        }
      });
      
      // Initialize saved chats list
      updateSavedChatsList();
    });
  </script>
</body>
</html>

EOF

    cd ../..
}

# Create startup script
create_startup_script() {
    log "Creating startup script..."
    
    cat > capsule-chat/start-capsule.sh << 'EOF'
#!/bin/bash

# Capsule Chat Startup Script
# Starts Ollama service and the backend server

set -e

echo "🚀 Starting Capsule Chat..."

# Check if Ollama is running
if ! curl -s http://localhost:11434 > /dev/null; then
    echo "⚠️  Starting Ollama service..."
    case $(uname -s) in
        "Linux")
            sudo systemctl start ollama
            ;;
        "Darwin")
            brew services start ollama 2>/dev/null || ollama serve &
            ;;
        *)
            ollama serve &
            ;;
    esac
    sleep 3
fi

# Start the backend server
cd backend
echo "🔧 Starting backend server on http://localhost:3000"
npm start
EOF

    chmod +x capsule-chat/start-capsule.sh
    
    # Create a simpler run script for daily use
    cat > capsule-chat/run.sh << 'EOF'
#!/bin/bash
cd "$(dirname "$0")"
./start-capsule.sh
EOF

    chmod +x capsule-chat/run.sh
}

# Create README
create_readme() {
    log "Creating documentation..."
    
    cat > capsule-chat/README.md << 'EOF'
# Capsule Chat - Local AI Assistant

A beautiful, feature-rich chat interface for local AI models powered by Ollama.

## Features

- 🎨 **Beautiful UI**: Gradient theme with glassmorphism design
- 🗣️ **Text-to-Speech**: Built-in speech synthesis for responses
- 💾 **Chat History**: Save and load conversations
- 🔧 **Multiple Models**: Support for various Ollama models
- 📁 **File Upload**: Image and video support (for vision models)
- ⚙️ **Tool Integration**: Web search, SSH, and vision capabilities

## Quick Start

### Method 1: Simple Start
```bash
cd capsule-chat
./run.sh
```

Then open your browser to: http://localhost:3000

### Method 2: Manual Start
1. Start Ollama (if not already running):
   ```bash
   # Linux
   sudo systemctl start ollama
   
   # macOS
   brew services start ollama
   ```

2. Start the backend:
   ```bash
   cd capsule-chat/backend
   npm start
   ```

3. Open http://localhost:3000 in your browser

## Available Models

The installation includes these models:
- **DeepSeek R1 1.5B**: Fast, lightweight model
- **Qwen2.5 3B**: Balanced performance
- **Gemma2 2B**: Google's efficient model
- **Llama 3.2 3B**: Meta's recommended model
- **Mistral 7B**: Powerful 7B parameter model
- **Llama 3.2 Vision 11B**: For image understanding

## Project Structure

```
capsule-chat/
├── backend/          # Node.js backend server
│   ├── server.js     # Main server file
│   ├── package.json  # Dependencies
│   └── .env          # Environment configuration
├── frontend/         # Web interface
│   └── index.html    # Main HTML file
├── start-capsule.sh  # Full startup script
├── run.sh           # Quick start script
└── README.md        # This file
```

## Configuration

### Backend Settings
Edit `backend/.env` to configure:
- **OLLAMA_URL**: Change if Ollama runs on different port
- **PORT**: Backend server port (default: 3000)

### Adding More Models
```bash
ollama pull model-name
```

### Speech Settings
The browser's built-in speech synthesis is used. For best results:
- Use Chrome or Edge
- Check browser permissions for audio
- Configure system speech settings

## Troubleshooting

### Ollama Not Starting
```bash
# Check Ollama status
ollama list

# Restart Ollama service
sudo systemctl restart ollama  # Linux
brew services restart ollama   # macOS
```

### Backend Connection Issues
1. Verify Ollama is running: `curl http://localhost:11434`
2. Check backend server: `curl http://localhost:3000/api/health`
3. Verify no other services are using port 3000

### Speech Not Working
1. Check browser console for errors
2. Ensure browser allows audio autoplay
3. Try different browsers (Chrome works best)

## Development

### Backend Development
```bash
cd backend
npm run dev  # Auto-restart on changes
```

### Adding Features
- Backend routes: `backend/server.js`
- Frontend UI: `frontend/index.html`
- Model integration: Modify `/api/chat` endpoint

## License

This project is provided as-is for educational and personal use.

## Support

For issues and questions:
1. Check the troubleshooting section above
2. Ensure all prerequisites are installed
3. Verify model downloads completed successfully

Enjoy your local AI assistant! 🚀
EOF
}

# Main installation function
main() {
    log "Starting Capsule Chat installation..."
    
    # Check prerequisites
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed. Please install curl first."
        exit 1
    fi
    
    if ! command -v node &> /dev/null; then
        error "Node.js is required but not installed. Please install Node.js first."
        exit 1
    fi
    
    if ! command -v npm &> /dev/null; then
        error "npm is required but not installed. Please install npm first."
        exit 1
    fi
    
    # Install Ollama
    install_ollama
    
    # Download models
    download_models
    
    # Setup backend and frontend
    setup_backend
    setup_frontend
    
    # Create startup scripts
    create_startup_script
    create_readme
    
    log "Installation completed successfully! 🎉"
    echo ""
    echo -e "${GREEN}Next steps:${NC}"
    echo "1. cd capsule-chat"
    echo "2. ./run.sh"
    echo "3. Open http://localhost:3000 in your browser"
    echo ""
    echo -e "${YELLOW}Note: The first startup might take a moment as services initialize.${NC}"
}

# Run installation
main
```

Save this as `install-capsule-chat.sh` and make it executable:

```bash
chmod +x install-capsule-chat.sh
./install-capsule-chat.sh
```

This comprehensive installation script will:

1. **Install Ollama** on Linux or macOS
2. **Download essential models** (smaller ones for faster setup)
3. **Set up the Node.js backend** with proper configuration
4. **Deploy the frontend** with all features
5. **Create startup scripts** for easy launching
6. **Generate documentation** with troubleshooting guide

After installation, users can simply run:
```bash
cd capsule-chat
./run.sh
```

Then open http://localhost:3000 in their browser to start using the chat interface!


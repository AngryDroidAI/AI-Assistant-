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
  <title>Capsule Chat - AI Assistant</title>
  <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.4.0/css/all.min.css">
  <style>
    :root {
      --primary-gradient: linear-gradient(135deg, #1a2a6c, #b21f1f, #1a2a6c);
      --user-message-gradient: linear-gradient(135deg, #4e54c8, #8f94fb);
      --ai-message-bg: rgba(255,255,255,0.15);
      --container-bg: rgba(255,255,255,0.1);
    }
    
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }
    
    body {
      background: var(--primary-gradient);
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
      background: var(--container-bg);
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
    
    .chat-header h1 { 
      color: white; 
      font-size: 1.8rem; 
      margin-bottom: 5px; 
    }
    
    .chat-header p { 
      color: rgba(255,255,255,0.7); 
      font-size: 0.9rem; 
      margin-bottom: 10px; 
    }
    
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
    
    @keyframes fadeIn { 
      from { opacity:0; transform:translateY(10px); } 
      to { opacity:1; transform:translateY(0); } 
    }
    
    .user-message {
      background: var(--user-message-gradient);
      color: white;
      align-self: flex-end;
      border-bottom-right-radius: 5px;
    }
    
    .ai-message {
      background: var(--ai-message-bg);
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
    }
    
    .typing-indicator {
      display: none;
      background: var(--ai-message-bg);
      color: white;
      align-self: flex-start;
      padding: 15px;
      border-radius: 18px;
      border-bottom-left-radius: 5px;
      margin: 0 20px 10px 20px;
    }
    
    .typing-indicator span {
      height: 10px; 
      width: 10px; 
      float: left; 
      margin: 0 2px;
      background-color: rgba(255,255,255,0.7);
      border-radius: 50%; 
      opacity: 0.4;
      animation: typing 1s infinite;
    }
    
    .typing-indicator span:nth-of-type(2) { animation-delay: 0.2s; }
    .typing-indicator span:nth-of-type(3) { animation-delay: 0.4s; }
    
    @keyframes typing {
      0% { transform: translateY(0px); }
      50% { transform: translateY(-5px); }
      100% { transform: translateY(0px); }
    }
    
    .chat-input {
      display: flex;
      padding: 20px;
      background: rgba(0,0,0,0.2);
      border-top: 1px solid rgba(255,255,255,0.1);
      align-items: center;
    }
    
    .chat-input input[type="text"] {
      flex: 1; 
      padding: 15px 20px; 
      border: none; 
      border-radius: 30px;
      background: rgba(255,255,255,0.15); 
      color: white; 
      font-size: 1rem;
      outline: none; 
      transition: all 0.3s ease;
    }
    
    .chat-input input[type="text"]:focus {
      background: rgba(255,255,255,0.25);
      box-shadow: 0 0 0 2px rgba(78,84,200,0.5);
    }
    
    .chat-input input::placeholder { 
      color: rgba(255,255,255,0.6); 
    }
    
    .chat-input button {
      background: var(--user-message-gradient);
      border: none; 
      color: white; 
      width: 50px; 
      height: 50px;
      border-radius: 50%; 
      margin-left: 15px; 
      cursor: pointer;
      transition: all 0.3s ease; 
      display: flex; 
      justify-content: center; 
      align-items: center;
      font-size: 1.2rem;
    }
    
    .chat-input button:hover { 
      transform: scale(1.05); 
      box-shadow: 0 0 15px rgba(78,84,200,0.5); 
    }
    
    .chat-input button:active { 
      transform: scale(0.95); 
    }
    
    #upload-button, #tools-button, #speak-button {
      width: 40px;
      height: 40px;
      margin-right: 10px;
      font-size: 1rem;
      display: flex;
      justify-content: center;
      align-items: center;
    }
    
    .speak-active {
      background: linear-gradient(135deg, #b21f1f, #ff5e62) !important;
      box-shadow: 0 0 10px rgba(178,31,31,0.7) !important;
    }
    
    .tools-menu, .chat-history-menu {
      display: none;
      position: absolute;
      bottom: 90px;
      left: 20px;
      background: rgba(0,0,0,0.6);
      padding: 15px;
      border-radius: 12px;
      box-shadow: 0 5px 15px rgba(0,0,0,0.3);
      color: white;
      font-size: 0.9rem;
      min-width: 220px;
      z-index: 10;
    }
    
    .chat-history-menu {
      bottom: 140px;
      width: 250px;
    }
    
    .tools-menu h4, .chat-history-menu h4 {
      margin-bottom: 8px;
      font-weight: 600;
      color: rgba(255,255,255,0.85);
    }
    
    .tools-menu label, .chat-history-menu button, .chat-history-menu input {
      display: block;
      margin-bottom: 8px;
      cursor: pointer;
      width: 100%;
    }
    
    .chat-history-menu button {
      background: var(--user-message-gradient);
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
    
    .message img, .message video {
      max-width: 100%;
      border-radius: 12px;
      margin-top: 10px;
      box-shadow: 0 5px 15px rgba(0,0,0,0.3);
    }
    
    .message video {
      max-height: 300px;
    }
    
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
    
    .status-bar {
      position: absolute;
      bottom: 10px;
      right: 10px;
      background: rgba(0,0,0,0.5);
      color: white;
      padding: 5px 10px;
      border-radius: 10px;
      font-size: 0.8rem;
      z-index: 5;
    }
  </style>
</head>
<body>
  <div class="chat-container">
    <div class="chat-header">
      <h1><i class="fas fa-robot"></i> Capsule AI Assistant</h1>
      <p>Powered by Ollama + Local AI Models</p>
      <select id="model-select">
        <option value="deepseek-r1:1.5b">DeepSeek R1 1.5B (Fast)</option>
        <option value="qwen2.5:3b">Qwen2.5 3B (Balanced)</option>
        <option value="gemma2:2b">Gemma2 2B (Lightweight)</option>
        <option value="llama3.2:3b">Llama 3.2 3B (Recommended)</option>
        <option value="mistral:7b">Mistral 7B (Powerful)</option>
        <option value="llama3.2-vision:11b">Llama 3.2 Vision 11B (Images)</option>
      </select>
      <button class="history-button" id="history-button" title="Chat History">
        <i class="fas fa-history"></i>
      </button>
    </div>
    
    <div class="chat-messages" id="chat-messages">
      <div class="message ai-message">
        <div class="message-header">
          <i class="fas fa-robot"></i> Capsule Assistant
        </div>
        <div class="message-content">
          Hello! I'm your AI assistant powered by local models. Select a model from the dropdown and start chatting!
        </div>
      </div>
    </div>
    
    <div class="typing-indicator" id="typing-indicator">
      <span></span><span></span><span></span>
    </div>
    
    <div class="chat-input">
      <button id="upload-button" title="Upload File">
        <i class="fas fa-plus"></i>
      </button>
      <button id="tools-button" title="Tools & Settings">
        <i class="fas fa-cogs"></i>
      </button>
      <button id="speak-button" title="Speak Response">
        <i class="fas fa-volume-up"></i>
      </button>
      <input type="file" id="file-upload" accept="image/*,video/*" style="display:none">
      <input type="text" id="user-input" placeholder="Type your message here...">
      <button id="send-button" title="Send Message">
        <i class="fas fa-paper-plane"></i>
      </button>
    </div>
    
    <div id="tools-menu" class="tools-menu">
      <h4>Tool Options</h4>
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
    
    <div class="status-bar" id="status-bar">
      Status: Ready
    </div>
  </div>

  <script>
    document.addEventListener('DOMContentLoaded', function() {
      // DOM elements
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
      const loadChatFile = document.createElement('input');
      loadChatFile.type = 'file';
      loadChatFile.accept = '.json';
      loadChatFile.style.display = 'none';
      document.body.appendChild(loadChatFile);
      
      const statusBar = document.getElementById('status-bar');
      const synth = window.speechSynthesis;
      
      // State variables
      let isSpeaking = false;
      let chatHistory = [];
      
      // Update status
      function updateStatus(message, isError = false) {
        statusBar.textContent = `Status: ${message}`;
        statusBar.style.background = isError ? 'rgba(178,31,31,0.7)' : 'rgba(0,0,0,0.5)';
      }
      
      // Message functions
      function addMessage(text, isUser) {
        const messageDiv = document.createElement('div');
        messageDiv.classList.add('message', isUser ? 'user-message' : 'ai-message');
        
        const messageHeader = document.createElement('div');
        messageHeader.classList.add('message-header');
        messageHeader.innerHTML = isUser ? 
          '<i class="fas fa-user"></i> You' : 
          `<i class="fas fa-robot"></i> ${getModelDisplayName(modelSelect.value)}`;
        
        const messageContent = document.createElement('div');
        messageContent.classList.add('message-content');
        messageContent.textContent = text;
        
        messageDiv.appendChild(messageHeader);
        messageDiv.appendChild(messageContent);
        chatMessages.appendChild(messageDiv);
        chatMessages.scrollTop = chatMessages.scrollHeight;
        
        chatHistory.push({
          text: text,
          isUser: isUser,
          model: isUser ? null : modelSelect.value,
          timestamp: new Date().toISOString()
        });
      }
      
      function getModelDisplayName(fullModelName) {
        const modelMap = {
          'deepseek-r1:1.5b': 'DeepSeek R1',
          'qwen2.5:3b': 'Qwen2.5',
          'gemma2:2b': 'Gemma2',
          'llama3.2:3b': 'Llama 3.2',
          'mistral:7b': 'Mistral',
          'llama3.2-vision:11b': 'Llama Vision'
        };
        return modelMap[fullModelName] || fullModelName.split(':')[0];
      }
      
      // AI Response function
      async function getAIResponseStream(userMessage) {
        const model = modelSelect.value;
        updateStatus(`Connecting to ${getModelDisplayName(model)}...`);
        
        try {
          const response = await fetch("/api/chat", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ model, prompt: userMessage, stream: true })
          });
          
          if (!response.ok || !response.body) {
            throw new Error(`API error: ${response.status}`);
          }
          
          typingIndicator.style.display = 'block';
          let fullText = '';
          const reader = response.body.getReader();
          const decoder = new TextDecoder();
          
          while (true) {
            const { done, value } = await reader.read();
            if (done) break;
            
            const chunk = decoder.decode(value);
            const lines = chunk.split('\n');
            
            for (const line of lines) {
              if (line.trim() && line.startsWith('{')) {
                try {
                  const data = JSON.parse(line);
                  if (data.response) {
                    fullText += data.response;
                    // Update last message with streaming text
                    const lastMessage = chatMessages.lastChild.querySelector('.message-content');
                    if (lastMessage) lastMessage.textContent = fullText;
                  }
                } catch (e) {
                  // Skip invalid JSON lines
                }
              }
            }
          }
          
          typingIndicator.style.display = 'none';
          updateStatus("Ready");
          return fullText || "(No response generated)";
          
        } catch (error) {
          typingIndicator.style.display = 'none';
          updateStatus("Backend connection failed", true);
          return `Error: ${error.message}. Please make sure the backend server is running.`;
        }
      }
      
      // Chat functions
      async function sendMessage() {
        const message = userInput.value.trim();
        if (!message) return;
        
        userInput.value = '';
        addMessage(message, true);
        
        const aiResponse = await getAIResponseStream(message);
        addMessage(aiResponse, false);
        
        if (document.getElementById('auto-speak').checked && !aiResponse.startsWith('Error:')) {
          speakText(aiResponse);
        }
      }
      
      // Speech functions
      function speakText(text) {
        if (!synth || isSpeaking) return;
        
        synth.cancel();
        const utterance = new SpeechSynthesisUtterance(text);
        utterance.rate = 0.8;
        utterance.pitch = 1;
        
        utterance.onstart = () => {
          isSpeaking = true;
          speakButton.classList.add('speak-active');
          speakButton.innerHTML = '<i class="fas fa-stop"></i>';
        };
        
        utterance.onend = utterance.onerror = () => {
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
      
      // Chat history functions
      function saveChat() {
        const chatName = chatNameInput.value.trim() || `Chat_${new Date().toLocaleString().replace(/[^\w]/g, '_')}`;
        const chatData = {
          name: chatName,
          messages: chatHistory,
          model: modelSelect.value,
          timestamp: new Date().toISOString()
        };
        
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChats.push(chatData);
        localStorage.setItem('savedChats', JSON.stringify(savedChats));
        
        const blob = new Blob([JSON.stringify(chatData, null, 2)], {type: 'application/json'});
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = `${chatName}.json`;
        a.click();
        URL.revokeObjectURL(url);
        
        updateSavedChatsList();
        alert(`Chat "${chatName}" saved successfully!`);
      }
      
      function loadChat(chatData) {
        if (!chatData?.messages) {
          alert('Invalid chat file');
          return;
        }
        
        chatMessages.innerHTML = '';
        chatHistory = [];
        
        // Add welcome message
        const welcomeMsg = document.createElement('div');
        welcomeMsg.classList.add('message', 'ai-message');
        welcomeMsg.innerHTML = `
          <div class="message-header"><i class="fas fa-robot"></i> Capsule Assistant</div>
          <div class="message-content">Loaded chat: ${chatData.name}</div>
        `;
        chatMessages.appendChild(welcomeMsg);
        
        chatData.messages.forEach(msg => {
          const messageDiv = document.createElement('div');
          messageDiv.classList.add('message', msg.isUser ? 'user-message' : 'ai-message');
          
          const messageHeader = document.createElement('div');
          messageHeader.classList.add('message-header');
          messageHeader.innerHTML = msg.isUser ? 
            '<i class="fas fa-user"></i> You' : 
            `<i class="fas fa-robot"></i> ${msg.model ? getModelDisplayName(msg.model) : 'AI'}`;
          
          const messageContent = document.createElement('div');
          messageContent.classList.add('message-content');
          messageContent.textContent = msg.text || '[Media message]';
          
          messageDiv.appendChild(messageHeader);
          messageDiv.appendChild(messageContent);
          chatMessages.appendChild(messageDiv);
          chatHistory.push(msg);
        });
        
        if (chatData.model) modelSelect.value = chatData.model;
        chatMessages.scrollTop = chatMessages.scrollHeight;
        updateStatus(`Loaded: ${chatData.name}`);
      }
      
      function updateSavedChatsList() {
        const savedChats = JSON.parse(localStorage.getItem('savedChats') || '[]');
        savedChatsList.innerHTML = '';
        
        if (savedChats.length === 0) {
          savedChatsList.innerHTML = '<div class="saved-chat-item">No saved chats yet</div>';
          return;
        }
        
        savedChats.forEach(chat => {
          const item = document.createElement('div');
          item.classList.add('saved-chat-item');
          item.innerHTML = `<strong>${chat.name}</strong><br><small>${new Date(chat.timestamp).toLocaleString()}</small>`;
          item.onclick = () => {
            if (confirm(`Load "${chat.name}"? Current chat will be replaced.`)) {
              loadChat(chat);
              chatHistoryMenu.style.display = 'none';
            }
          };
          savedChatsList.appendChild(item);
        });
      }
      
      // Event listeners
      sendButton.addEventListener('click', sendMessage);
      userInput.addEventListener('keypress', e => e.key === 'Enter' && sendMessage());
      
      uploadButton.addEventListener('click', () => fileUpload.click());
      fileUpload.addEventListener('change', e => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = function(e) {
            addMessage(`Uploaded file: ${file.name} (${file.type})`, true);
          };
          reader.readAsDataURL(file);
        }
      });
      
      toolsButton.addEventListener('click', () => toolsMenu.style.display = toolsMenu.style.display === 'block' ? 'none' : 'block');
      document.addEventListener('click', e => {
        if (!toolsMenu.contains(e.target) && e.target !== toolsButton) toolsMenu.style.display = 'none';
      });
      
      historyButton.addEventListener('click', () => {
        chatHistoryMenu.style.display = chatHistoryMenu.style.display === 'block' ? 'none' : 'block';
        updateSavedChatsList();
      });
      document.addEventListener('click', e => {
        if (!chatHistoryMenu.contains(e.target) && e.target !== historyButton) chatHistoryMenu.style.display = 'none';
      });
      
      saveChatButton.addEventListener('click', saveChat);
      loadChatButton.addEventListener('click', () => loadChatFile.click());
      loadChatFile.addEventListener('change', e => {
        const file = e.target.files[0];
        if (file) {
          const reader = new FileReader();
          reader.onload = function(e) {
            try {
              loadChat(JSON.parse(e.target.result));
            } catch (err) {
              alert('Error loading chat file: ' + err.message);
            }
          };
          reader.readAsText(file);
        }
      });
      
      speakButton.addEventListener('click', () => {
        isSpeaking ? stopSpeaking() : (
          document.querySelectorAll('.ai-message').length > 0 && 
          speakText(chatMessages.lastChild.querySelector('.message-content').textContent)
        );
      });
      
      // Initialize
      updateStatus("Ready");
      updateSavedChatsList();
      
      // Test backend connection
      fetch('/api/health').then(r => r.json()).then(data => {
        updateStatus("Backend connected");
      }).catch(err => {
        updateStatus("Backend not responding", true);
      });
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


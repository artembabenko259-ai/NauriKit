import { useState, useEffect } from 'react'
import reactLogo from './assets/react.svg'
import './App.css'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  const sendPing = async () => {
    if ((window as any).naurikit) {
      try {
        const response = await (window as any).naurikit.invoke("ping");
        alert("Response from Zig: " + response);
      } catch (err) {
        alert("Error: " + err);
      }
    } else {
      alert("NauriKit IPC bridge not available!");
    }
  }

  const showMessage = async () => {
    await (window as any).naurikit.message("Hello", "This is a native Windows MessageBox from Zig!");
  }

  const writeAndReadFile = async () => {
    try {
      await (window as any).naurikit.writeFile("test.txt", "Hello from React!");
      const content = await (window as any).naurikit.readFile("test.txt");
      alert("File read successfully: " + content);
    } catch (e) {
      alert("FS Error: " + e);
    }
  }

  const minimize = () => {
    (window as any).naurikit.minimize();
  }

  const maximize = () => {
    (window as any).naurikit.maximize();
  }

  const closeWindow = () => {
    (window as any).naurikit.quit();
  }

  const startDrag = () => {
    (window as any).naurikit.startDrag();
  }

  return (
    <>
      {/* Custom Titlebar */}
      <div 
        className="titlebar" 
        onMouseDown={startDrag}
        onDoubleClick={maximize}
      >
        <div className="titlebar-title">NauriKit App</div>
        <div className="titlebar-controls" onMouseDown={(e) => e.stopPropagation()}>
          <button className="titlebar-btn" onClick={minimize}>&#x2013;</button>
          <button className="titlebar-btn" onClick={maximize}>&#9723;</button>
          <button className="titlebar-btn close-btn" onClick={closeWindow}>&#10005;</button>
        </div>
      </div>

      <div className="app-content">
        <div>
          <a href="https://react.dev" target="_blank">
            <img src={reactLogo} className="logo react" alt="React logo" />
          </a>
        </div>
        <h1>NauriKit + Vite + React</h1>
        <div className="card">
          <button onClick={() => setCount((count) => count + 1)}>
            count is {count}
          </button>
          <button onClick={sendPing} style={{ marginLeft: "10px" }}>
            Ping Zig Backend
          </button>
          <button onClick={showMessage} style={{ marginLeft: "10px" }}>
            Show Native Dialog
          </button>
          <button onClick={writeAndReadFile} style={{ marginLeft: "10px" }}>
            Test File System
          </button>
          <button onClick={minimize} style={{ marginLeft: "10px" }}>
            Minimize Window
          </button>
          <p>
            Edit <code>src/App.tsx</code> and save to test HMR
          </p>
        </div>
        <p className="read-the-docs">
          Click on the Vite and React logos to learn more
        </p>
      </div>
    </>
  )
}

export default App

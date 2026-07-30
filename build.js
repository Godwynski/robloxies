const fs = require('fs');
const path = require('path');

function bundle(file) {
    let content = fs.readFileSync(file, 'utf8');
    
    // Replace require("module.path")
    content = content.replace(/require\(['"]([^'"]+)['"]\)/g, (match, modulePath) => {
        // Convert module.path to module/path.lua
        const filePath = modulePath.replace(/\./g, '/') + '.lua';
        
        if (fs.existsSync(filePath)) {
            console.log(`Bundling: ${filePath}`);
            // Wrap the module in a function to isolate its scope, then immediately invoke it
            return `(function()\n${bundle(filePath)}\nend)()`;
        } else {
            console.warn(`WARNING: Could not find ${filePath}`);
            return match;
        }
    });
    
    return content;
}

const outFile = 'dist/main.lua';
if (!fs.existsSync('dist')) {
    fs.mkdirSync('dist');
}

console.log('Starting bundle process...');
const finalCode = bundle('init.lua');
fs.writeFileSync(outFile, finalCode);
console.log(`Successfully bundled to ${outFile}!`);

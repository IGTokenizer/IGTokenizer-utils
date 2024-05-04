const { createCanvas, loadImage } = require('canvas');
const fs = require('fs');
const axios = require('axios');
const FormData = require('form-data');
require('dotenv').config();  // Ensure your .env file has the JWT token

async function downloadImage(postId, outputPath) {
    try {
        const response = await axios({
            method: 'GET',
            url: `https://instagram.com/p/${postId}/media/?size=l`,
            responseType: 'stream'
        });

        const writer = fs.createWriteStream(outputPath);
        response.data.pipe(writer);

        return new Promise((resolve, reject) => {
            writer.on('finish', resolve);
            writer.on('error', reject);
        });
    } catch (error) {
        console.error('Error downloading image:', error);
        throw error;
    }
}

async function addTextAndOverlay(inputImagePath, ownerWallet, postId) {
    try {
        const inputImage = await loadImage(inputImagePath);
        const canvas = createCanvas(inputImage.width, inputImage.height);
        const ctx = canvas.getContext('2d');
        ctx.drawImage(inputImage, 0, 0, inputImage.width, inputImage.height);
        ctx.font = '40px Arial';
        ctx.fillStyle = 'white';
        ctx.fillText(postId, 345, 162);
        ctx.fillText(ownerWallet, 615, 245);

        const overlayImagePathParts = postId.split('/');
        const overlayImageFileName = overlayImagePathParts[overlayImagePathParts.length - 1];
        const downloadedImagePath = `./posts/${overlayImageFileName}.jpg`;
        await downloadImage(postId, downloadedImagePath);
        const overlayImage = await loadImage(downloadedImagePath);
        ctx.drawImage(overlayImage, 860, 270, 950, 720);

        const outputImagePath = `./nfts/${postId}.png`;
        const out = fs.createWriteStream(outputImagePath);
        const stream = canvas.createPNGStream();
        stream.pipe(out);
        
        return new Promise((resolve, reject) => {
            out.on('finish', () => {
                console.log('The image was saved successfully.');
                resolve(outputImagePath);
            });
            out.on('error', reject);
        });
    } catch (err) {
        console.error('Error:', err);
    }
}

async function uploadToIPFS(filePath) {
    const formData = new FormData();
    formData.append('file', fs.createReadStream(filePath));
    
    const metadata = JSON.stringify({
        name: `NFT-${filePath}`
    });
    formData.append('pinataMetadata', metadata);

    const options = JSON.stringify({
        cidVersion: 0
    });
    formData.append('pinataOptions', options);

    try {
        const response = await axios.post('https://api.pinata.cloud/pinning/pinFileToIPFS', formData, {
            headers: {
                ...formData.getHeaders(),
                Authorization: `Bearer ${process.env.PINATA_JWT}`
            }
        });
        return response.data;
    } catch (error) {
        console.error('Error uploading to IPFS:', error);
        throw error;
    }
}

// Example usage
async function processImage() {
    const imagePath = await addTextAndOverlay('background.jpg', '0xE23131232423424234H32H4D32', 'C5r2ACGtTuP');
    const ipfsResult = await uploadToIPFS(imagePath);
    console.log('IPFS Upload Result:', ipfsResult);
}

processImage();

const scriptUrl = document.currentScript.src;
const relativePath = 'images.json';
const dataUrl = new URL(relativePath, scriptUrl);
window.addEventListener('load', function() {
    fetch(dataUrl).then(resp => resp.json()).then(images => {
        document.querySelectorAll('img').forEach(img => {
            const src = img.getAttribute('data-src');
            if (images[src]) {
                img.src = `https://picture-service.secondlife.com/${images[src]}/320x240.jpg`;
                img.width = 240;
                img.height = 240;
            }
        });
    });
});

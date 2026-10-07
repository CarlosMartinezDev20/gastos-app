/// Whether [downloadTextFile] can save files on this platform.
const canDownloadFiles = false;

Future<void> downloadTextFile(String name, String content, String mimeType) =>
    throw UnsupportedError('Descargas no disponibles en esta plataforma');

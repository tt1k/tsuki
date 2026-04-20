function fileFromEntry(entry) {
  return new Promise((resolve, reject) => {
    entry.file(resolve, reject);
  });
}

function readAllEntries(reader) {
  return new Promise((resolve, reject) => {
    const entries = [];

    const loop = () => {
      reader.readEntries(
        (chunk) => {
          if (!chunk.length) {
            resolve(entries);
            return;
          }

          entries.push(...chunk);
          loop();
        },
        (error) => reject(error)
      );
    };

    loop();
  });
}

async function collectFilesFromEntry(entry, parentPath = "") {
  if (entry.isFile) {
    const file = await fileFromEntry(entry);
    return [{ path: `${parentPath}${entry.name}`, file }];
  }

  if (entry.isDirectory) {
    const nextParent = `${parentPath}${entry.name}/`;
    const reader = entry.createReader();
    const children = await readAllEntries(reader);
    const nestedGroups = await Promise.all(
      children.map((child) => collectFilesFromEntry(child, nextParent))
    );
    return nestedGroups.flat();
  }

  return [];
}

export async function collectFilesFromDataTransfer(dataTransfer) {
  const items = Array.from(dataTransfer?.items ?? []);
  const hasWebkitEntry = items.some((item) => typeof item.webkitGetAsEntry === "function");

  if (hasWebkitEntry) {
    const rootEntries = items
      .map((item) => item.webkitGetAsEntry?.())
      .filter((entry) => entry && (entry.isFile || entry.isDirectory));

    const groups = await Promise.all(rootEntries.map((entry) => collectFilesFromEntry(entry)));
    return groups.flat();
  }

  const fallbackFiles = Array.from(dataTransfer?.files ?? []);
  return fallbackFiles.map((file) => ({
    path: file.webkitRelativePath || file.name,
    file
  }));
}

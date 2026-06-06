'use client';

import { getDataloom } from '@lark-apaas/client-toolkit/dataloom';
import { getDefaultBucketId } from '@lark-apaas/client-toolkit/tools/storage';

import type { UploadFileData } from './types';

export async function uploadFile(file: File): Promise<UploadFileData> {
  const dataloom = await getDataloom();
  const defaultBucketId = getDefaultBucketId();

  if (!defaultBucketId) {
    throw new Error('Default bucket id is not available');
  }

  const bucket = dataloom.storage.from(defaultBucketId);

  const result = await bucket.uploadFile(file);

  if (result.error) {
    throw result.error;
  }

  return {
    id: result.data.id,
    filePath: result.data.file_path,
    bucketId: result.data.bucket_id,
    url: result.data.download_url,
  };
}

import React from 'react';

// TODO: Build the gallery page
// - List messages
// - Create message form (requires >= 1000 SWT)
// - Like/Alert buttons on each message

export default function GalleryPage({ params }: { params: { slug: string } }) {
  return (
    <div>
      <h1>Gallery: {params.slug}</h1>
      <p>TODO: Message list, create form, like/alert buttons</p>
    </div>
  );
}

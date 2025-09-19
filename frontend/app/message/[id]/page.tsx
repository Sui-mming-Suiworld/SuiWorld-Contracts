import React from 'react';

// TODO: Build the message detail page
// - Show message content
// - For managers: Show vote/resolve buttons for hype/scam proposals

export default function MessagePage({ params }: { params: { id: string } }) {
  return (
    <div>
      <h1>Message: {params.id}</h1>
      <p>TODO: Message detail, manager voting UI</p>
    </div>
  );
}

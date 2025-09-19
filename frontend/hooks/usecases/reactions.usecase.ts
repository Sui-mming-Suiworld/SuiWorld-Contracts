// TODO: Implement logic for liking/alerting messages
export const useReactions = () => {
  const likeMessage = (messageId: string) => {
    // Call backend to increment like count
  };

  const alertMessage = (messageId: string) => {
    // Call backend to increment alert count
  };

  return { likeMessage, alertMessage };
};

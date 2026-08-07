const { SQSClient, SendMessageCommand } = require('@aws-sdk/client-sqs');
const config = require('../config');

const client = new SQSClient({ region: config.awsRegion });

async function enqueueReview(review) {
  if (!config.reviewModerationQueueUrl) {
    throw new Error('REVIEW_MODERATION_QUEUE_URL is not configured');
  }
  await client.send(new SendMessageCommand({
    QueueUrl: config.reviewModerationQueueUrl,
    MessageBody: JSON.stringify({
      userId: review.userId,
      productId: review.productId,
      text: review.text,
      photoKey: review.photoKey || null,
    }),
  }));
}

module.exports = { enqueueReview };

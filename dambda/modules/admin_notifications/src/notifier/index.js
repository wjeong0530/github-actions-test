const { SNSClient, PublishCommand } = require('@aws-sdk/client-sns');
const sns = new SNSClient({});

exports.handler = async (event) => {
  for (const record of event.Records || []) {
    const product = record.dynamodb?.NewImage || record.dynamodb?.OldImage || {};
    const productId = product.itemId?.S || 'unknown';
    await sns.send(new PublishCommand({
      TopicArn: process.env.TOPIC_ARN,
      Subject: `[DAMBDA] Product ${record.eventName.toLowerCase()}`,
      Message: JSON.stringify({ eventName: record.eventName, productId, occurredAt: new Date().toISOString() }),
    }));
  }
};

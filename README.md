# ☁️ Detecting and redacting PII data with S3 Object Lambda and Amazon Comprehend and Textract


![AWS](https://img.shields.io/badge/AWS-Cloud-orange?style=for-the-badge&logo=amazon-aws&logoColor=white)
![Terraform](https://img.shields.io/badge/Terraform-%E2%89%A51.9-844FBA?style=for-the-badge&logo=terraform&logoColor=white)
![Lambda](https://img.shields.io/badge/AWS_Lambda-Python_3.12-yellow?style=for-the-badge&logo=aws-lambda)
![Comprehend](https://img.shields.io/badge/Amazon_Comprehend-PII_Detection-red?style=for-the-badge&logo=amazonaws)
![S3](https://img.shields.io/badge/S3_Object_Lambda-Real_Time-blue?style=for-the-badge)
![PDF](https://img.shields.io/badge/PDF_Support-Enabled-green?style=for-the-badge)
![Compliance](https://img.shields.io/badge/Compliance-HIPAA_Ready-purple?style=for-the-badge)
![Status](https://img.shields.io/badge/Status-Production_Ready-success?style=for-the-badge)

# ** AWS Serverless - Detecting and redacting PII data with S3 Object Lambda and Amazon Comprehend and Textract**

Implementing PII (Personally Identifiable Information) redaction using S3 Object Lambda and Amazon Comprehend allows you to dynamically mask sensitive data during retrieval without altering the original files.

## Key Features
- **Serverless**: S3 and Lambda
- **Multi-Format Support**: PDF, TXT, JSON, CSV files
- **ML-Powered Detection**: 25+ PII entity types using Amazon Comprehend
- **OCR and Large File Support**: Amazon Textract to handle scanned PDF's, async processing with no size limit
- **Real-Time Processing**: Redaction happens during object retrieval
- **Original Data Unchanged**: Files in S3 remain intact
- **Flexible Configuration**: Customize mask mode, character, and PII types per access point
- **Scalable Architecture**: Automatic scaling with Lambda and Comprehend
- **Cost-Effective**: Pay only for what you use

## Supported File Formats

| Format | Extension | Processing |
|--------|-----------|------------|
| PDF | `.pdf` | Text extraction → Redaction → PDF regeneration |
| Text | `.txt` | Direct text redaction |
| JSON | `.json` | Structure-preserving redaction |
| CSV | `.csv` | Cell-by-cell redaction |

## Architecture
Implementing PII (Personally Identifiable Information) redaction using S3 Object Lambda and Amazon Comprehend allows you to dynamically mask sensitive data during retrieval without altering the original files.

The workflow involves an S3 GET request that triggers a Lambda function via an S3 Object Lambda Access Point. This function sends the object content to Amazon Comprehend for PII detection and returns the redacted version to the requester

[Detecting and redacting PII data with S3 Object Lambda and Amazon Comprehend - Amazon Simple Storage Service](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html)

With [S3 Object Lambda](https://aws.amazon.com/s3/features/object-lambda) and a prebuilt AWS Lambda function powered by Amazon Comprehend, you can protect PII data retrieved from S3 before returning it to an application. Specifically, you can use the prebuilt [Lambda function](https://aws.amazon.com/lambda/) as a redacting function and attach it to an S3 Object Lambda Access Point. When an application (for example, an analytics application) sends [standard S3 GET requests](https://docs.aws.amazon.com/AmazonS3/latest/API/API_GetObject.html), these requests made through the S3 Object Lambda Access Point invoke the prebuilt redacting Lambda function to detect and redact PII data retrieved from an underlying data source through a supporting S3 access point. Then, the S3 Object Lambda Access Point returns the redacted result back to the application.

![image.png](/images/ol-comprehend-image-global.png)


- [Prerequisites: Create an IAM user with permissions](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-prerequisites)
    
    IAM user requires the following AWS managed policies:
    
    - [AmazonS3FullAccess](https://console.aws.amazon.com/iam/home?#/policies/arn:aws:iam::aws:policy/AmazonS3FullAccess$jsonEditor) – Grants permissions to all Amazon S3 actions, including permissions to create and use an Object Lambda Access Point.
    - [AWSLambda_FullAccess](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/AWSLambda_FullAccess$jsonEditor) – Grants permissions to all Lambda actions.
    - [AWSCloudFormationFullAccess](https://console.aws.amazon.com/iam/home?#/policies/arn:aws:iam::aws:policy/AWSCloudFormationFullAccess$serviceLevelSummary) – Grants permissions to all AWS CloudFormation actions.
    - [IAMFullAccess](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/IAMFullAccess$jsonEditor) – Grants permissions to all IAM actions.
    - [IAMAccessAnalyzerReadOnlyAccess](https://console.aws.amazon.com/iam/home#/policies/arn:aws:iam::aws:policy/IAMAccessAnalyzerReadOnlyAccess$jsonEditor) – Grants permissions to read all access information provided by IAM Access Analyzer.
    - IAM user requires a customer managed policy.
- [Step 1: Create an S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step1)
    - note: **Block Public Access settings for this bucket**, keep the default settings (**Block *all* public access** is enabled).
        
        We recommend that you keep all Block Public Access settings enabled unless you need to turn off one or more of them for your use case. For more information about blocking public access, see [Blocking public access to your Amazon S3 storage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html).
        
- [Step 2: Upload a file to the S3 bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step2)
- [Step 3: Create an S3 access point](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step3)
    - use an S3 Object Lambda Access Point to access and transform the original data, you must create an S3 access point and associate it with the S3 bucket that you created in [Step 1](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step1). The access point must be in the same AWS Region as the objects you want to transform.
    
- [Step 4: Configure and deploy a prebuilt Lambda function](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step4)
    
    To redact PII data, configure and deploy the prebuilt AWS Lambda function `ComprehendPiiRedactionS3ObjectLambda` for use with your S3 Object Lambda Access Point.
    
    1. For **Application settings**, under **Application name**, keep the default value (`ComprehendPiiRedactionS3ObjectLambda`) for this tutorial.
        
        (Optional) You can enter the name that you want to give to this application. You might want to do this if you plan to configure multiple Lambda functions for different access needs for the same shared dataset.
        
    2. For **MaskCharacter**, keep the default value (). The mask character replaces each character in the redacted PII entity.
    3. For **MaskMode**, keep the default value (**MASK**). The **MaskMode** value specifies whether the PII entity is redacted with the `MASK` character or the `PII_ENTITY_TYPE` value.
    4. To redact the specified types of data, for **PiiEntityTypes**, keep the default value **ALL**. The **PiiEntityTypes** value specifies the PII entity types to be considered for redaction.
        
        For more information about the list of supported PII entity types, see [Detect Personally Identifiable Information (PII)](https://docs.aws.amazon.com/comprehend/latest/dg/how-pii.html) in the *Amazon Comprehend Developer Guide*.
        
    5. Keep the remaining settings set to the defaults.
        
        (Optional) If you want to configure additional settings for your specific use case, see the **Readme file** section on the left side of the page.
        
    6. Select the check box next to **I acknowledge that this app creates custom IAM roles**.
    7. Choose **Deploy**.
    8. On the new application's page, under **Resources**, choose the **Logical ID** of the Lambda function that you deployed to review the function on the Lambda function page.
- [Step 5: Create an S3 Object Lambda Access Point](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step5)
    - On the **Object Lambda Access Points** page, choose **Create Object Lambda Access Point**.
        1. For **Object Lambda Access Point name**, enter the name that you want to use for the Object Lambda Access Point (for example, **`tutorial-pii-object-lambda-accesspoint`**).
        2. For **Supporting Access Point**, enter or browse to the standard access point that you created in [Step 3](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step3) (for example, **`tutorial-pii-access-point`**), and then choose **Choose supporting Access Point**.
        3. For **S3 APIs**, to retrieve objects from the S3 bucket for Lambda function to process, select **GetObject**.
        4. For **Invoke Lambda function**, you can choose either of the following two options for this tutorial.
            - Choose **Choose from functions in your account** and choose the Lambda function that you deployed in [Step 4](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step4) (for example, **`serverlessrepo-ComprehendPiiRedactionS3ObjectLambda`**) from the **Lambda function** dropdown list.
            - Choose **Enter ARN**, and then enter the Amazon Resource Name (ARN) of the Lambda function that you created in [Step 4](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step4).
        5. For **Lambda function version**, choose **$LATEST** (the latest version of the Lambda function that you deployed in [Step 4](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step4)).
        6. (Optional) If you need your Lambda function to recognize and process GET requests with range and part number headers, select **Lambda function supports requests using range** and **Lambda function supports requests using part numbers**. Otherwise, clear these two check boxes.
            
            For more information about how to use range or part numbers with S3 Object Lambda, see [Working with Range and partNumber headers](https://docs.aws.amazon.com/AmazonS3/latest/userguide/range-get-olap.html).
            
        7. (Optional) Under **Payload - *optional***, add JSON text to provide your Lambda function with additional information.
            
            A payload is optional JSON text that you can provide to your Lambda function as input for all invocations coming from a specific S3 Object Lambda Access Point. To customize the behaviors for multiple Object Lambda Access Points that invoke the same Lambda function, you can configure payloads with different parameters, thereby extending the flexibility of your Lambda function.
            
            For more information about payload, see [Event context format and usage](https://docs.aws.amazon.com/AmazonS3/latest/userguide/olap-event-context.html).
            
        8. (Optional) For **Request metrics - *optional***, choose **Disable** or **Enable** to add Amazon S3 monitoring to your Object Lambda Access Point. Request metrics are billed at the standard Amazon CloudWatch rate. For more information, see [CloudWatch pricing](https://aws.amazon.com/cloudwatch/pricing/).
        9. Under **Object Lambda Access Point policy - *optional***, keep the default setting.
            
            (Optional) You can set a resource policy. This resource policy grants the `GetObject` API permission to use the specified Object Lambda Access Point.
            
- [Step 6: Use the S3 Object Lambda Access Point to retrieve the redacted file](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step6)
- [Step 7: Clean up](https://docs.aws.amazon.com/AmazonS3/latest/userguide/tutorial-s3-object-lambda-redact-pii.html#ol-pii-step7)
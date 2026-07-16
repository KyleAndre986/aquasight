# AquaSight

AquaSight is a mobile-based water clarity classification application developed as an academic project. The application uses a Convolutional Neural Network (CNN) with MobileNetV2 transfer learning to classify captured or uploaded water images into three categories: **Clear**, **Cloudy**, or **Murky**.

The trained model was converted to TensorFlow Lite (TFLite) and integrated into a Flutter mobile application, allowing image classification to be performed directly on the device.

## Features

- Capture water images using the device camera
- Upload existing images from the device gallery
- Classify water images as Clear, Cloudy, or Murky
- Display classification confidence scores
- Reject uncertain predictions using a confidence threshold
- Perform image classification offline using TensorFlow Lite

## Technologies Used

- Flutter
- Dart
- Python
- TensorFlow / Keras
- TensorFlow Lite
- MobileNetV2
- Convolutional Neural Networks (CNN)

## How It Works

1. The user captures or uploads an image of a water sample.
2. The image is processed by the TensorFlow Lite model integrated into the application.
3. The model classifies the image into one of three categories:
   - Clear
   - Cloudy
   - Murky
4. The application displays the predicted classification and confidence score.
5. Predictions below the configured confidence threshold are treated as uncertain.

## Model Development

The image classification model was developed using MobileNetV2 with transfer learning. A custom dataset of water images was prepared and divided into training, validation, and testing sets.

The trained model was evaluated under controlled testing conditions before being converted to TensorFlow Lite for integration into the Flutter mobile application.

## Results

The model achieved **95.83% test accuracy under controlled testing conditions**.

Field testing was also conducted using new water samples in different real-world conditions. The field evaluation showed lower performance compared with controlled testing, highlighting limitations in the model's ability to generalize to variations in lighting, backgrounds, containers, and environmental conditions.

These results identified the need for a larger and more diverse training dataset for future improvements.

## Known Limitations

- Classification performance may be affected by lighting conditions.
- Different backgrounds and water containers may influence predictions.
- The dataset used for training was relatively limited.
- Real-world field performance was lower than controlled test performance.
- AquaSight evaluates visible water clarity only and does not determine whether water is chemically or microbiologically safe to drink.

## Project Context

AquaSight was developed as an academic Computer Engineering project focused on exploring the use of machine learning and mobile applications for image-based water clarity assessment.

The project provided hands-on experience with dataset preparation, CNN model training, TensorFlow Lite model deployment, Flutter mobile application development, and real-world model evaluation.

## Future Improvements

Possible improvements include:

- Expanding the dataset with more diverse water samples
- Improving dataset variation in lighting, backgrounds, and containers
- Improving model generalization for real-world conditions
- Further optimizing the model for mobile deployment
- Improving the application's user interface and user experience

## Disclaimer

AquaSight is an academic prototype intended for water clarity classification based on visual appearance. It is not a substitute for professional water quality testing and should not be used to determine whether water is safe for consumption.
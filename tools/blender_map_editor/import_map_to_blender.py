import os

import bpy

ASSET_BASE_DIR = r"C:\Users\pc\Old PC Mimic\All Important Folders\thuctap\projects\Prompt-Craft-Arena\client\assets\environments"
MAP_SIZE = (1000.0, 1000.0)

CONFIG = {
    "tree": [
        (68.0, 1000.0, -0.0, 2.0, 0.0, "tree_2.glb", False),
        (200.0, 1005.0, -0.0, 3.0, 0.0, "tree_3.glb", False),
        (300.0, 1005.0, -0.0, 2.0, 0.0, "tree_4.glb", False),
        (400.0, 1005.0, -0.0, 5.0, 0.0, "tree_5.glb", False),
        (500.0, 1005.0, -0.0, 3.0, 0.0, "tree_6.glb", False),
        (600.0, 1005.0, -0.0, 3.0, 0.0, "tree_7.glb", False),
        (700.0, 1005.0, -0.0, 4.0, 0.0, "tree_8.glb", False),
        (800.0, 1005.0, -0.0, 9.0, 0.0, "tree_9.glb", False),
        (900.0, 1005.0, -0.0, 10.0, 0.0, "tree_10.glb", False),
        (950.0, 1005.0, -0.0, 4.0, 0.0, "tree_3.glb", False),
        (330.0, 1015.0, 0.5, 3.0, 0.0, "tree_3.glb", False),
        (250.0, 1025.0, 0.6, 2.0, 0.0, "tree_4.glb", False),
        (470.0, 1025.0, 0.8, 5.0, 0.0, "tree_5.glb", False),
        (420.0, 1015.0, 0.9, 3.0, 0.0, "tree_6.glb", False),
        (690.0, 1025.0, 1.4, 3.0, 0.0, "tree_7.glb", False),
        (290.0, 1025.0, 0.1, 4.0, 0.0, "tree_8.glb", False),
        (550.0, 1015.0, 0.9, 9.0, 0.0, "tree_9.glb", False),
        (620.0, 1025.0, 0.3, 10.0, 0.0, "tree_10.glb", False),
        (850.0, 1015.0, 0.7, 4.0, 0.0, "tree_3.glb", False),
        (0.0, 932.0, 0.1, 1.8, 0.0, "tree_2.glb", False),
        (-5.0, 800.0, 0.2, 2.8, 0.0, "tree_3.glb", False),
        (-5.0, 700.0, 0.3, 1.8, 0.0, "tree_4.glb", False),
        (-5.0, 600.0, 0.4, 4.8, 0.0, "tree_5.glb", False),
        (-5.0, 500.0, 0.5, 2.8, 0.0, "tree_6.glb", False),
        (-5.0, 400.0, 0.6, 2.8, 0.0, "tree_7.glb", False),
        (-5.0, 300.0, 0.7, 3.5, 0.0, "tree_8.glb", False),
        (-5.0, 200.0, 0.8, 9.0, 0.0, "tree_9.glb", False),
        (-5.0, 100.0, 0.9, 10.0, 0.0, "tree_10.glb", False),
        (-5.0, 50.0, 1.0, 4.0, 0.0, "tree_3.glb", False),
        (-15.0, 670.0, 1.5, 3.2, 0.0, "tree_3.glb", False),
        (-25.0, 750.0, 1.6, 2.2, 0.0, "tree_4.glb", False),
        (-25.0, 530.0, 1.8, 5.2, 0.0, "tree_5.glb", False),
        (-15.0, 580.0, 1.9, 3.2, 0.0, "tree_6.glb", False),
        (-25.0, 310.0, 2.4, 3.2, 0.0, "tree_7.glb", False),
        (-25.0, 710.0, 1.1, 4.2, 0.0, "tree_8.glb", False),
        (-15.0, 450.0, 1.9, 9.2, 0.0, "tree_9.glb", False),
        (-25.0, 380.0, 1.3, 10.2, 0.0, "tree_10.glb", False),
        (-15.0, 150.0, 1.7, 4.2, 0.0, "tree_3.glb", False),
        (932.0, 0.0, 0.5, 2.3, 0.0, "tree_2.glb", False),
        (800.0, -5.0, 0.8, 3.2, 0.0, "tree_3.glb", False),
        (700.0, -5.0, 0.34, 2.1, 0.0, "tree_4.glb", False),
        (600.0, -5.0, 0.1, 5.5, 0.0, "tree_5.glb", False),
        (500.0, -5.0, 0.41, 2.6, 0.0, "tree_6.glb", False),
        (400.0, -5.0, 0.5, 2.8, 0.0, "tree_7.glb", False),
        (300.0, -5.0, 0.6, 3.6, 0.0, "tree_8.glb", False),
        (200.0, -5.0, 0.1, 8.6, 0.0, "tree_9.glb", False),
        (100.0, -5.0, 0.9, 9.0, 0.0, "tree_10.glb", False),
        (50.0, -5.0, 0.4, 4.2, 0.0, "tree_3.glb", False),
        (670.0, -15.0, 0.5, 3.0, 0.0, "tree_3.glb", False),
        (750.0, -25.0, 0.6, 2.0, 0.0, "tree_4.glb", False),
        (530.0, -25.0, 0.7, 5.0, 0.0, "tree_5.glb", False),
        (420.0, -15.0, 0.8, 3.0, 0.0, "tree_6.glb", False),
        (310.0, -25.0, 1.2, 3.0, 0.0, "tree_7.glb", False),
        (710.0, -25.0, 0.12, 4.0, 0.0, "tree_8.glb", False),
        (450.0, -15.0, 0.94, 9.0, 0.0, "tree_9.glb", False),
        (380.0, -25.0, 0.34, 10.0, 0.0, "tree_10.glb", False),
        (150.0, -15.0, 0.72, 4.0, 0.0, "tree_3.glb", False),
        (1000.0, 68.0, 0.41, 1.8, 0.0, "tree_2.glb", False),
        (1005.0, 200.0, 0.42, 2.8, 0.0, "tree_3.glb", False),
        (1005.0, 300.0, 0.43, 1.8, 0.0, "tree_4.glb", False),
        (1005.0, 400.0, 0.44, 4.8, 0.0, "tree_5.glb", False),
        (1005.0, 500.0, 0.45, 2.8, 0.0, "tree_6.glb", False),
        (1005.0, 600.0, 0.46, 2.8, 0.0, "tree_7.glb", False),
        (1005.0, 700.0, 0.47, 3.5, 0.0, "tree_8.glb", False),
        (1005.0, 800.0, 0.48, 9.0, 0.0, "tree_9.glb", False),
        (1005.0, 900.0, 0.49, 10.0, 0.0, "tree_10.glb", False),
        (1005.0, 950.0, 1.4, 4.0, 0.0, "tree_3.glb", False),
        (1015.0, 330.0, 1.45, 3.2, 0.0, "tree_3.glb", False),
        (1025.0, 250.0, 1.46, 2.2, 0.0, "tree_4.glb", False),
        (1025.0, 470.0, 1.48, 5.2, 0.0, "tree_5.glb", False),
        (1015.0, 420.0, 1.49, 3.2, 0.0, "tree_6.glb", False),
        (1025.0, 690.0, 2.44, 3.2, 0.0, "tree_7.glb", False),
        (1025.0, 290.0, 1.41, 4.2, 0.0, "tree_8.glb", False),
        (1015.0, 550.0, 1.49, 9.2, 0.0, "tree_9.glb", False),
        (1025.0, 620.0, 1.43, 10.2, 0.0, "tree_10.glb", False),
        (1015.0, 850.0, 1.47, 4.2, 0.0, "tree_3.glb", False),
        (156.9, 493.5, 1.3, 14.57, 0.0, "tree_10.glb", False),
        (160.0, 520.0, 1.8, 5.2, 0.0, "tree_5.glb", False),
        (148.8, 542.2, 1.9, 9.2, 0.0, "tree_9.glb", False),
        (151.0, 561.4, 1.8, 3.33, 0.0, "tree_5.glb", False),
        (163.4, 541.8, 1.3, 9.41, 0.0, "tree_10.glb", False),
        (506.5, 843.1, -6.01, 14.57, 0.0, "tree_10.glb", False),
        (480.0, 840.0, 2.91, 5.2, 0.0, "tree_5.glb", False),
        (457.8, 851.2, -0.33, 9.2, 0.0, "tree_9.glb", False),
        (438.6, 849.0, -0.23, 3.33, 0.0, "tree_5.glb", False),
        (458.2, 836.6, -6.01, 9.41, 0.0, "tree_10.glb", False),
        (493.5, 156.9, -6.01, 14.57, 0.0, "tree_10.glb", False),
        (520.0, 160.0, -3.37, 5.2, 0.0, "tree_5.glb", False),
        (542.2, 148.8, -3.47, 9.2, 0.0, "tree_9.glb", False),
        (561.4, 151.0, -3.37, 3.33, 0.0, "tree_5.glb", False),
        (541.8, 163.4, -6.01, 9.41, 0.0, "tree_10.glb", False),
        (843.1, 506.5, -4.98, 14.57, 0.0, "tree_10.glb", False),
        (840.0, 480.0, 1.8, 5.2, 0.0, "tree_5.glb", False),
        (851.2, 457.8, 1.9, 9.2, 0.0, "tree_9.glb", False),
        (849.0, 438.6, 1.8, 3.33, 0.0, "tree_5.glb", False),
        (836.6, 458.2, -4.98, 9.41, 0.0, "tree_10.glb", False),
        (177.3, 325.1, 1.8, 7.04, 0.0, "tree_5.glb", False),
        (168.6, 361.1, 1.3, 12.74, 0.0, "tree_10.glb", False),
        (167.6, 393.8, 0.3, 2.41, 0.0, "tree_4.glb", False),
        (822.7, 674.9, 4.94, 7.04, 0.0, "tree_5.glb", False),
        (831.4, 638.9, 4.44, 12.74, 0.0, "tree_10.glb", False),
        (832.4, 606.2, 3.44, 2.41, 0.0, "tree_4.glb", False),
        (165.5, 236.0, 1.8, 4.76, 0.0, "tree_5.glb", False),
        (155.6, 247.3, 1.3, 15.62, 0.0, "tree_10.glb", False),
        (183.5, 250.4, 1.3, 21.47, 0.0, "tree_10.glb", False),
        (289.2, 333.9, 1.3, 14.44, 0.0, "tree_10.glb", False),
        (834.5, 764.0, 4.94, 4.76, 0.0, "tree_5.glb", False),
        (844.4, 752.7, 4.44, 15.62, 0.0, "tree_10.glb", False),
        (816.5, 749.6, 4.44, 21.47, 0.0, "tree_10.glb", False),
        (710.8, 666.1, 4.44, 14.44, 0.0, "tree_10.glb", False),
        (229.5, 507.7, 1.3, 19.46, 0.0, "tree_10.glb", False),
        (229.6, 536.3, 1.8, 4.35, 0.0, "tree_5.glb", False),
        (228.3, 551.2, 1.9, 9.2, 0.0, "tree_9.glb", False),
        (229.6, 565.7, 2.13, 3.33, 0.0, "tree_5.glb", False),
        (240.2, 591.4, 0.3, 1.99, 0.0, "tree_4.glb", False),
        (326.1, 524.4, 0.3, 1.79, 0.0, "tree_4.glb", False),
        (321.1, 541.5, 1.8, 4.48, 0.0, "tree_5.glb", False),
        (306.8, 567.4, 1.75, 14.57, 0.0, "tree_10.glb", False),
        (287.0, 587.1, 0.3, 1.58, 0.0, "tree_4.glb", False),
        (266.8, 597.4, 1.42, 22.38, 0.0, "tree_10.glb", False),
        (770.5, 492.3, 4.44, 19.46, 0.0, "tree_10.glb", False),
        (770.4, 463.7, 4.94, 4.35, 0.0, "tree_5.glb", False),
        (771.7, 448.8, 5.04, 9.2, 0.0, "tree_9.glb", False),
        (770.4, 434.3, 5.27, 3.33, 0.0, "tree_5.glb", False),
        (759.8, 408.6, 3.44, 1.99, 0.0, "tree_4.glb", False),
        (673.9, 475.6, 3.44, 1.79, 0.0, "tree_4.glb", False),
        (678.9, 458.5, 4.94, 4.48, 0.0, "tree_5.glb", False),
        (693.2, 432.6, 4.89, 14.57, 0.0, "tree_10.glb", False),
        (713.0, 412.9, 3.44, 1.58, 0.0, "tree_4.glb", False),
        (733.2, 402.6, 4.56, 22.38, 0.0, "tree_10.glb", False),
        (393.4, 399.8, 1.3, 16.01, 0.0, "tree_10.glb", False),
        (260.8, 413.3, 1.8, 4.59, 0.0, "tree_5.glb", False),
        (606.6, 600.2, 4.44, 16.01, 0.0, "tree_10.glb", False),
        (739.2, 586.7, 4.94, 4.59, 0.0, "tree_5.glb", False),
        (430.3, 234.4, 1.3, 18.65, 0.0, "tree_10.glb", False),
        (521.4, 221.0, 1.63, 6.29, 0.0, "tree_5.glb", False),
        (537.7, 289.8, 0.68, 4.79, 0.0, "tree_8.glb", False),
        (449.2, 273.4, 1.63, 3.58, 0.0, "tree_5.glb", False),
        (513.6, 258.5, 1.3, 11.9, 0.0, "tree_10.glb", False),
        (569.7, 765.6, 4.44, 18.65, 0.0, "tree_10.glb", False),
        (478.6, 779.0, 4.77, 6.29, 0.0, "tree_5.glb", False),
        (462.3, 710.2, 3.82, 4.79, 0.0, "tree_8.glb", False),
        (550.8, 726.6, 4.77, 3.58, 0.0, "tree_5.glb", False),
        (486.4, 741.5, 4.44, 11.9, 0.0, "tree_10.glb", False),
        (646.1, 692.8, 1.6, 2.2, 0.0, "tree_4.glb", False),
        (353.9, 307.2, 4.74, 2.2, 0.0, "tree_4.glb", False),
    ],
    "rock": [
        (140.0, 1000.0, 3.14, 8.0, 0.0, "rock_13.glb", False),
        (165.0, 1000.0, 3.14, 10.0, 0.0, "rock_15.glb", False),
        (192.0, 1003.0, -0.0, 20.0, 10.0, "rock_12.glb", False),
        (210.0, 1015.0, -0.0, 40.0, 0.0, "rock_1.glb", False),
        (310.0, 1015.0, -0.0, 40.0, 0.0, "rock_2.glb", False),
        (410.0, 1025.0, -0.0, 20.0, 0.0, "rock_3.glb", False),
        (510.0, 1015.0, -0.0, 20.0, 0.0, "rock_4.glb", False),
        (610.0, 1005.0, -0.0, 40.0, 0.0, "rock_5.glb", False),
        (710.0, 1015.0, -0.0, 40.0, 0.0, "rock_6.glb", False),
        (810.0, 1025.0, -0.0, 40.0, 0.0, "rock_7.glb", False),
        (910.0, 1015.0, -0.0, 40.0, 0.0, "rock_8.glb", False),
        (940.0, 1005.0, -0.0, 20.0, 0.0, "rock_9.glb", False),
        (850.0, 1015.0, -0.0, 40.0, 0.0, "rock_10.glb", False),
        (750.0, 1025.0, -0.0, 40.0, 0.0, "rock_11.glb", False),
        (650.0, 1015.0, -0.0, 40.0, 11.9, "rock_12.glb", False),
        (550.0, 1005.0, -0.0, 5.0, 0.0, "rock_13.glb", False),
        (450.0, 1015.0, -0.0, 5.0, 0.0, "rock_14.glb", False),
        (350.0, 1025.0, -0.0, 5.0, 0.0, "rock_15.glb", False),
        (285.0, 1025.0, 0.14, 35.0, 0.0, "rock_1.glb", False),
        (385.0, 1015.0, 1.17, 45.0, 0.0, "rock_2.glb", False),
        (238.0, 1025.0, 2.46, 23.0, 0.0, "rock_3.glb", False),
        (235.0, 1015.0, 1.5, 27.0, 0.0, "rock_4.glb", False),
        (320.0, 1025.0, 2.0, 38.0, 0.0, "rock_5.glb", False),
        (770.0, 1025.0, 2.3, 33.0, 0.0, "rock_6.glb", False),
        (441.0, 1025.0, 1.2, 45.0, 0.0, "rock_7.glb", False),
        (182.0, 1005.0, 0.6, 47.0, 0.0, "rock_8.glb", False),
        (924.0, 1015.0, 4.5, 18.0, 0.0, "rock_9.glb", False),
        (503.0, 1015.0, 3.2, 43.0, 0.0, "rock_10.glb", False),
        (642.0, 1005.0, 2.2, 39.0, 0.0, "rock_11.glb", False),
        (401.0, 1015.0, 2.1, 37.0, 10.8, "rock_12.glb", False),
        (255.0, 1015.0, 0.9, 6.0, 0.0, "rock_13.glb", False),
        (762.0, 1025.0, 4.2, 7.0, 0.0, "rock_14.glb", False),
        (696.0, 1015.0, 2.8, 8.0, 0.0, "rock_15.glb", False),
        (0.0, 860.0, 1.57, 8.0, 0.0, "rock_13.glb", False),
        (0.0, 835.0, 1.57, 10.0, 0.0, "rock_15.glb", False),
        (-3.0, 808.0, -1.57, 20.0, 10.0, "rock_12.glb", False),
        (-15.0, 790.0, -1.57, 40.0, 0.0, "rock_1.glb", False),
        (-15.0, 690.0, -1.57, 40.0, 0.0, "rock_2.glb", False),
        (-25.0, 590.0, -1.57, 20.0, 0.0, "rock_3.glb", False),
        (-15.0, 490.0, -1.57, 20.0, 0.0, "rock_4.glb", False),
        (-5.0, 390.0, -1.57, 40.0, 0.0, "rock_5.glb", False),
        (-15.0, 290.0, -1.57, 40.0, 0.0, "rock_6.glb", False),
        (-25.0, 190.0, -1.57, 40.0, 0.0, "rock_7.glb", False),
        (-15.0, 90.0, -1.57, 40.0, 0.0, "rock_8.glb", False),
        (-5.0, 60.0, -1.57, 20.0, 0.0, "rock_9.glb", False),
        (-15.0, 150.0, -1.57, 40.0, 0.0, "rock_10.glb", False),
        (-25.0, 250.0, -1.57, 40.0, 0.0, "rock_11.glb", False),
        (-15.0, 350.0, -1.57, 40.0, 11.4, "rock_12.glb", False),
        (-5.0, 450.0, -1.57, 5.0, 0.0, "rock_13.glb", False),
        (-15.0, 550.0, -1.57, 5.0, 0.0, "rock_14.glb", False),
        (-25.0, 650.0, -1.57, 5.0, 0.0, "rock_15.glb", False),
        (-25.0, 715.0, 0.14, 35.0, 0.0, "rock_1.glb", False),
        (-15.0, 615.0, 1.17, 45.0, 0.0, "rock_2.glb", False),
        (-25.0, 762.0, 2.46, 23.0, 0.0, "rock_3.glb", False),
        (-15.0, 765.0, 1.5, 27.0, 0.0, "rock_4.glb", False),
        (-25.0, 680.0, 2.0, 38.0, 0.0, "rock_5.glb", False),
        (-25.0, 230.0, 2.3, 33.0, 0.0, "rock_6.glb", False),
        (-25.0, 559.0, 1.2, 45.0, 0.0, "rock_7.glb", False),
        (-5.0, 818.0, 0.6, 47.0, 0.0, "rock_8.glb", False),
        (-15.0, 76.0, 4.5, 18.0, 0.0, "rock_9.glb", False),
        (-15.0, 497.0, 3.2, 43.0, 0.0, "rock_10.glb", False),
        (-5.0, 358.0, 2.2, 39.0, 0.0, "rock_11.glb", False),
        (-15.0, 599.0, 2.1, 37.0, 11.9, "rock_12.glb", False),
        (-15.0, 745.0, 0.9, 6.0, 0.0, "rock_13.glb", False),
        (-25.0, 238.0, 4.2, 7.0, 0.0, "rock_14.glb", False),
        (-15.0, 304.0, 2.8, 8.0, 0.0, "rock_15.glb", False),
        (860.0, 0.0, -0.0, 8.0, 0.0, "rock_13.glb", False),
        (835.0, 0.0, -0.0, 10.0, 0.0, "rock_15.glb", False),
        (808.0, -3.0, -3.14, 20.0, 10.0, "rock_12.glb", False),
        (790.0, -15.0, -3.14, 40.0, 0.0, "rock_1.glb", False),
        (690.0, -15.0, -3.14, 40.0, 0.0, "rock_2.glb", False),
        (590.0, -25.0, -3.14, 20.0, 0.0, "rock_3.glb", False),
        (490.0, -15.0, -3.14, 20.0, 0.0, "rock_4.glb", False),
        (390.0, -5.0, -3.14, 40.0, 0.0, "rock_5.glb", False),
        (290.0, -15.0, -3.14, 40.0, 0.0, "rock_6.glb", False),
        (190.0, -25.0, -3.14, 40.0, 0.0, "rock_7.glb", False),
        (90.0, -15.0, -3.14, 40.0, 0.0, "rock_8.glb", False),
        (60.0, -5.0, -3.14, 20.0, 0.0, "rock_9.glb", False),
        (150.0, -15.0, -3.14, 40.0, 0.0, "rock_10.glb", False),
        (250.0, -25.0, -3.14, 40.0, 0.0, "rock_11.glb", False),
        (350.0, -15.0, -3.14, 40.0, 13.4, "rock_12.glb", False),
        (450.0, -5.0, -3.14, 5.0, 0.0, "rock_13.glb", False),
        (550.0, -15.0, -3.14, 5.0, 0.0, "rock_14.glb", False),
        (650.0, -25.0, -3.14, 5.0, 0.0, "rock_15.glb", False),
        (715.0, -25.0, 0.14, 35.0, 0.0, "rock_1.glb", False),
        (615.0, -15.0, 1.17, 45.0, 0.0, "rock_2.glb", False),
        (762.0, -25.0, 2.46, 23.0, 0.0, "rock_3.glb", False),
        (765.0, -15.0, 1.5, 27.0, 0.0, "rock_4.glb", False),
        (680.0, -25.0, 2.0, 38.0, 0.0, "rock_5.glb", False),
        (230.0, -25.0, 2.3, 33.0, 0.0, "rock_6.glb", False),
        (559.0, -25.0, 1.2, 45.0, 0.0, "rock_7.glb", False),
        (818.0, -5.0, 0.6, 47.0, 0.0, "rock_8.glb", False),
        (76.0, -15.0, 4.5, 18.0, 0.0, "rock_9.glb", False),
        (497.0, -15.0, 3.2, 43.0, 0.0, "rock_10.glb", False),
        (358.0, -5.0, 2.2, 39.0, 0.0, "rock_11.glb", False),
        (599.0, -15.0, 2.1, 37.0, 8.8, "rock_12.glb", False),
        (745.0, -15.0, 0.9, 6.0, 0.0, "rock_13.glb", False),
        (238.0, -25.0, 4.2, 7.0, 0.0, "rock_14.glb", False),
        (304.0, -15.0, 2.8, 8.0, 0.0, "rock_15.glb", False),
        (1000.0, 140.0, -1.57, 8.0, 0.0, "rock_13.glb", False),
        (1000.0, 165.0, -1.57, 10.0, 0.0, "rock_15.glb", False),
        (1003.0, 192.0, 1.57, 20.0, 10.0, "rock_12.glb", False),
        (1015.0, 210.0, 1.57, 40.0, 0.0, "rock_1.glb", False),
        (1015.0, 310.0, 1.57, 40.0, 0.0, "rock_2.glb", False),
        (1025.0, 410.0, 1.57, 20.0, 0.0, "rock_3.glb", False),
        (1015.0, 510.0, 1.57, 20.0, 0.0, "rock_4.glb", False),
        (1005.0, 610.0, 1.57, 40.0, 0.0, "rock_5.glb", False),
        (1015.0, 710.0, 1.57, 40.0, 0.0, "rock_6.glb", False),
        (1025.0, 810.0, 1.57, 40.0, 0.0, "rock_7.glb", False),
        (1015.0, 910.0, 1.57, 40.0, 0.0, "rock_8.glb", False),
        (1005.0, 940.0, 1.57, 20.0, 0.0, "rock_9.glb", False),
        (1015.0, 850.0, 1.57, 40.0, 0.0, "rock_10.glb", False),
        (1025.0, 750.0, 1.57, 40.0, 0.0, "rock_11.glb", False),
        (1015.0, 650.0, 1.57, 40.0, 0.0, "rock_12.glb", False),
        (1005.0, 550.0, 1.57, 5.0, 0.0, "rock_13.glb", False),
        (1015.0, 450.0, 1.57, 5.0, 0.0, "rock_14.glb", False),
        (1025.0, 350.0, 1.57, 5.0, 0.0, "rock_15.glb", False),
        (1025.0, 285.0, 0.14, 35.0, 0.0, "rock_1.glb", False),
        (1015.0, 385.0, 1.17, 45.0, 0.0, "rock_2.glb", False),
        (1025.0, 238.0, 2.46, 23.0, 0.0, "rock_3.glb", False),
        (1015.0, 235.0, 1.5, 27.0, 0.0, "rock_4.glb", False),
        (1025.0, 320.0, 2.0, 38.0, 0.0, "rock_5.glb", False),
        (1025.0, 770.0, 2.3, 33.0, 0.0, "rock_6.glb", False),
        (1025.0, 441.0, 1.2, 45.0, 0.0, "rock_7.glb", False),
        (1005.0, 182.0, 0.6, 47.0, 0.0, "rock_8.glb", False),
        (1015.0, 924.0, 4.5, 18.0, 0.0, "rock_9.glb", False),
        (1015.0, 503.0, 3.2, 43.0, 0.0, "rock_10.glb", False),
        (1005.0, 642.0, 2.2, 39.0, 0.0, "rock_11.glb", False),
        (1015.0, 401.0, 2.1, 37.0, 0.0, "rock_12.glb", False),
        (1015.0, 255.0, 0.9, 6.0, 0.0, "rock_13.glb", False),
        (320.0, 180.0, 3.4, 30.0, 0.0, "rock_14.glb", False),
        (680.0, 820.0, 0.2, 30.0, 0.0, "rock_14.glb", False),
        (160.4, 494.4, 3.16, 9.31, 0.0, "rock_14.glb", False),
        (505.6, 839.6, -1.59, 9.31, 0.0, "rock_14.glb", False),
        (494.4, 160.4, -1.59, 9.31, 0.0, "rock_14.glb", False),
        (839.6, 505.6, -3.13, 9.31, 0.0, "rock_14.glb", False),
        (194.9, 454.0, -1.19, 13.93, 0.0, "rock_4.glb", False),
        (145.7, 399.8, -0.58, 31.52, 9.1, "rock_12.glb", False),
        (153.4, 330.5, -0.65, 43.13, 0.0, "rock_7.glb", False),
        (193.3, 422.2, -2.16, 24.13, 0.0, "rock_5.glb", False),
        (186.2, 356.7, -2.36, 23.82, 0.0, "rock_11.glb", False),
        (805.1, 546.0, 1.95, 13.93, 0.0, "rock_4.glb", False),
        (854.3, 600.2, 2.56, 31.52, 9.1, "rock_12.glb", False),
        (846.6, 669.5, 2.49, 43.13, 0.0, "rock_7.glb", False),
        (806.7, 577.8, 0.98, 24.13, 0.0, "rock_5.glb", False),
        (813.8, 643.3, 0.78, 23.82, 0.0, "rock_11.glb", False),
        (167.6, 229.1, 1.09, 32.48, 0.0, "rock_7.glb", False),
        (259.2, 309.0, -1.3, 19.56, 0.0, "rock_11.glb", False),
        (832.4, 770.9, 4.23, 32.48, 0.0, "rock_7.glb", False),
        (740.8, 691.0, 1.84, 19.56, 0.0, "rock_11.glb", False),
        (218.0, 592.3, -1.76, 16.64, 0.0, "rock_5.glb", False),
        (272.1, 621.3, 1.7, 21.19, 0.0, "rock_7.glb", False),
        (782.0, 407.7, 1.38, 16.64, 0.0, "rock_5.glb", False),
        (727.9, 378.7, 4.85, 21.19, 0.0, "rock_7.glb", False),
        (277.6, 423.5, 3.11, 18.71, 0.0, "rock_14.glb", False),
        (354.1, 434.6, -0.67, 18.71, 0.0, "rock_14.glb", False),
        (379.7, 385.1, -2.62, 17.14, 0.0, "rock_5.glb", False),
        (256.0, 433.1, -1.55, 28.67, 0.0, "rock_7.glb", False),
        (722.4, 576.5, 6.25, 18.71, 0.0, "rock_14.glb", False),
        (645.9, 565.4, 2.47, 18.71, 0.0, "rock_14.glb", False),
        (620.3, 614.9, 0.52, 17.14, 0.0, "rock_5.glb", False),
        (744.0, 566.9, 1.59, 28.67, 0.0, "rock_7.glb", False),
        (467.8, 239.4, 2.48, 18.01, 0.0, "rock_14.glb", False),
        (514.2, 269.7, 4.66, 18.01, 0.0, "rock_14.glb", False),
        (457.9, 296.3, 6.67, 18.01, 0.0, "rock_14.glb", False),
        (421.6, 258.3, -2.16, 24.13, 0.0, "rock_5.glb", False),
        (503.9, 318.1, 0.98, 16.48, 0.0, "rock_4.glb", False),
        (541.8, 237.2, -1.07, 27.73, 11.4, "rock_12.glb", False),
        (460.3, 295.7, -2.67, 29.17, 0.0, "rock_11.glb", False),
        (467.7, 237.0, -1.76, 11.09, 0.0, "rock_4.glb", False),
        (532.2, 760.6, 5.62, 18.01, 0.0, "rock_14.glb", False),
        (485.8, 730.3, 7.8, 18.01, 0.0, "rock_14.glb", False),
        (542.1, 703.7, 9.81, 18.01, 0.0, "rock_14.glb", False),
        (578.4, 741.7, 0.98, 24.13, 0.0, "rock_5.glb", False),
        (496.1, 681.9, 4.12, 16.48, 0.0, "rock_4.glb", False),
        (458.2, 762.8, 2.07, 27.73, 11.4, "rock_12.glb", False),
        (539.7, 704.3, 0.47, 29.17, 0.0, "rock_11.glb", False),
        (532.3, 763.0, 1.38, 11.09, 0.0, "rock_4.glb", False),
    ],
    "wall": [
        (20.0, 20.0, 2.35, 15.0, 0.0, "wall_4.glb", False),
        (20.0, 980.0, 0.77, 15.0, 0.0, "wall_4.glb", False),
        (980.0, 20.0, -2.35, 15.0, 0.0, "wall_4.glb", False),
        (980.0, 980.0, -0.77, 15.0, 0.0, "wall_4.glb", False),
        (100.0, 1000.0, 3.14, 10.0, 0.0, "wall_5.glb", False),
        (900.0, 0.0, -0.0, 10.0, 0.0, "wall_5.glb", False),
        (1000.0, 100.0, 1.57, 10.0, 0.0, "wall_5.glb", False),
        (0.0, 900.0, -1.57, 10.0, 0.0, "wall_5.glb", False),
        (135.0, 630.0, 0.2, 10.0, 0.0, "wall_5.glb", False),
        (205.0, 660.0, 0.6, 10.0, 0.0, "wall_5.glb", False),
        (370.0, 865.0, 1.37, 10.0, 0.0, "wall_5.glb", False),
        (340.0, 795.0, 0.97, 10.0, 0.0, "wall_5.glb", False),
        (630.0, 135.0, -1.77, 10.0, 0.0, "wall_5.glb", False),
        (660.0, 205.0, -2.17, 10.0, 0.0, "wall_5.glb", False),
        (865.0, 370.0, -2.84, 10.0, 0.0, "wall_5.glb", False),
        (795.0, 340.0, -2.54, 10.0, 0.0, "wall_5.glb", False),
        (225.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (270.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (315.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (360.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (405.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (450.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (495.0, 1000.0, 3.14, 10.0, 0.0, "wall_3.glb", False),
        (535.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (565.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (595.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (625.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (655.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (685.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (715.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (745.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (775.0, 1000.0, 3.14, 8.0, 0.0, "wall_2.glb", False),
        (810.0, 1000.0, 3.14, 9.0, 0.0, "wall_1.glb", False),
        (840.0, 1000.0, 3.14, 9.0, 0.0, "wall_1.glb", False),
        (870.0, 1000.0, 3.14, 9.0, 0.0, "wall_1.glb", False),
        (900.0, 1000.0, 3.14, 9.0, 0.0, "wall_1.glb", False),
        (930.0, 1000.0, 3.14, 9.0, 0.0, "wall_1.glb", False),
        (775.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (730.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (685.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (640.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (595.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (550.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (505.0, 0.0, -0.0, 10.0, 0.0, "wall_3.glb", False),
        (465.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (435.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (405.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (375.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (345.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (315.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (285.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (255.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (225.0, 0.0, -0.0, 8.0, 0.0, "wall_2.glb", False),
        (190.0, 0.0, -0.0, 9.0, 0.0, "wall_1.glb", False),
        (160.0, 0.0, -0.0, 9.0, 0.0, "wall_1.glb", False),
        (130.0, 0.0, -0.0, 9.0, 0.0, "wall_1.glb", False),
        (100.0, 0.0, -0.0, 9.0, 0.0, "wall_1.glb", False),
        (70.0, 0.0, -0.0, 9.0, 0.0, "wall_1.glb", False),
        (1000.0, 225.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 270.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 315.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 360.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 405.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 450.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 495.0, 1.57, 10.0, 0.0, "wall_3.glb", False),
        (1000.0, 535.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 565.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 595.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 625.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 655.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 685.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 715.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 745.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 775.0, 1.57, 8.0, 0.0, "wall_2.glb", False),
        (1000.0, 810.0, 1.57, 9.0, 0.0, "wall_1.glb", False),
        (1000.0, 840.0, 1.57, 9.0, 0.0, "wall_1.glb", False),
        (1000.0, 870.0, 1.57, 9.0, 0.0, "wall_1.glb", False),
        (1000.0, 900.0, 1.57, 9.0, 0.0, "wall_1.glb", False),
        (1000.0, 930.0, 1.57, 9.0, 0.0, "wall_1.glb", False),
        (0.0, 775.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 730.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 685.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 640.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 595.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 550.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 505.0, -1.57, 10.0, 0.0, "wall_3.glb", False),
        (0.0, 465.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 435.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 405.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 375.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 345.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 315.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 285.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 255.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 225.0, -1.57, 8.0, 0.0, "wall_2.glb", False),
        (0.0, 190.0, -1.57, 9.0, 0.0, "wall_1.glb", False),
        (0.0, 160.0, -1.57, 9.0, 0.0, "wall_1.glb", False),
        (0.0, 130.0, -1.57, 9.0, 0.0, "wall_1.glb", False),
        (0.0, 100.0, -1.57, 9.0, 0.0, "wall_1.glb", False),
        (0.0, 70.0, -1.57, 9.0, 0.0, "wall_1.glb", False),
        (139.9, 555.1, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (140.3, 530.4, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (141.4, 505.1, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (151.5, 572.0, 0.27, 4.42, 0.0, "wall_5.glb", False),
        (166.9, 561.3, -1.39, 5.24, 0.0, "wall_2.glb", False),
        (172.3, 539.0, -1.39, 5.68, 0.0, "wall_2.glb", False),
        (176.0, 515.4, -1.51, 6.4, 0.0, "wall_2.glb", False),
        (444.9, 860.1, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (469.6, 859.7, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (494.9, 858.6, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (428.0, 848.5, -4.99, 4.42, 0.0, "wall_5.glb", False),
        (438.7, 833.1, -3.32, 5.24, 0.0, "wall_2.glb", False),
        (461.0, 827.7, -3.32, 5.68, 0.0, "wall_2.glb", False),
        (484.6, 824.0, -3.21, 6.4, 0.0, "wall_2.glb", False),
        (555.1, 139.9, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (530.4, 140.3, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (505.1, 141.4, -3.14, 5.96, 0.0, "wall_2.glb", False),
        (572.0, 151.5, -4.99, 4.42, 0.0, "wall_5.glb", False),
        (561.3, 166.9, -3.32, 5.24, 0.0, "wall_2.glb", False),
        (539.0, 172.3, -3.32, 5.68, 0.0, "wall_2.glb", False),
        (515.4, 176.0, -3.21, 6.4, 0.0, "wall_2.glb", False),
        (860.1, 444.9, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (859.7, 469.6, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (858.6, 494.9, -1.57, 5.96, 0.0, "wall_2.glb", False),
        (848.5, 428.0, -6.01, 4.42, 0.0, "wall_5.glb", False),
        (833.1, 438.7, -1.39, 5.24, 0.0, "wall_2.glb", False),
        (827.7, 461.0, -1.39, 5.68, 0.0, "wall_2.glb", False),
        (824.0, 484.6, -1.51, 6.4, 0.0, "wall_2.glb", False),
        (166.7, 429.1, -2.53, 11.25, 0.0, "wall_2.glb", False),
        (146.8, 364.9, -1.59, 11.25, 0.0, "wall_2.glb", False),
        (184.3, 313.0, -0.4, 11.25, 0.0, "wall_2.glb", False),
        (833.3, 570.9, 0.61, 11.25, 0.0, "wall_2.glb", False),
        (853.2, 635.1, 1.55, 11.25, 0.0, "wall_2.glb", False),
        (815.7, 687.0, 2.75, 11.25, 0.0, "wall_2.glb", False),
        (199.7, 241.1, -2.76, 11.25, 0.0, "wall_2.glb", False),
        (235.5, 259.1, -2.57, 8.13, 0.0, "wall_2.glb", False),
        (261.5, 285.0, -2.3, 8.13, 0.0, "wall_2.glb", False),
        (280.1, 316.0, -2.04, 8.13, 0.0, "wall_2.glb", False),
        (800.3, 758.9, 0.38, 11.25, 0.0, "wall_2.glb", False),
        (764.5, 740.9, 0.57, 8.13, 0.0, "wall_2.glb", False),
        (738.5, 715.0, 0.84, 8.13, 0.0, "wall_2.glb", False),
        (719.9, 684.0, 1.1, 8.13, 0.0, "wall_2.glb", False),
        (228.5, 606.5, -2.7, 5.76, 0.0, "wall_3.glb", False),
        (254.1, 620.0, -2.52, 5.76, 0.0, "wall_3.glb", False),
        (218.6, 567.3, -1.6, 5.54, 0.0, "wall_1.glb", False),
        (219.4, 537.2, -1.6, 5.54, 0.0, "wall_1.glb", False),
        (215.6, 508.8, -1.88, 5.54, 0.0, "wall_1.glb", False),
        (288.2, 605.5, -0.74, 5.54, 0.0, "wall_1.glb", False),
        (308.3, 581.4, -1.0, 5.54, 0.0, "wall_1.glb", False),
        (323.4, 554.8, -1.13, 5.54, 0.0, "wall_1.glb", False),
        (335.0, 526.4, -1.25, 5.54, 0.0, "wall_1.glb", False),
        (227.5, 496.0, -3.12, 5.24, 0.0, "wall_2.glb", False),
        (239.1, 512.7, -1.58, 5.24, 0.0, "wall_2.glb", False),
        (238.3, 534.2, -1.58, 5.24, 0.0, "wall_2.glb", False),
        (237.8, 555.2, -1.58, 5.24, 0.0, "wall_2.glb", False),
        (242.6, 575.9, -2.24, 5.24, 0.0, "wall_2.glb", False),
        (260.6, 586.2, -2.93, 5.24, 0.0, "wall_2.glb", False),
        (279.9, 581.0, -3.94, 5.24, 0.0, "wall_2.glb", False),
        (295.4, 563.4, -4.12, 5.24, 0.0, "wall_2.glb", False),
        (307.4, 544.9, -4.23, 5.24, 0.0, "wall_2.glb", False),
        (316.5, 525.6, -4.39, 5.24, 0.0, "wall_2.glb", False),
        (328.5, 509.7, -3.33, 5.24, 0.0, "wall_2.glb", False),
        (771.5, 393.5, 0.44, 5.76, 0.0, "wall_3.glb", False),
        (745.9, 380.0, 0.62, 5.76, 0.0, "wall_3.glb", False),
        (781.4, 432.7, 1.54, 5.54, 0.0, "wall_1.glb", False),
        (780.6, 462.8, 1.54, 5.54, 0.0, "wall_1.glb", False),
        (784.4, 491.2, 1.26, 5.54, 0.0, "wall_1.glb", False),
        (711.8, 394.5, 2.4, 5.54, 0.0, "wall_1.glb", False),
        (691.7, 418.6, 2.15, 5.54, 0.0, "wall_1.glb", False),
        (676.6, 445.2, 2.01, 5.54, 0.0, "wall_1.glb", False),
        (665.0, 473.6, 1.89, 5.54, 0.0, "wall_1.glb", False),
        (772.5, 504.0, 0.02, 5.24, 0.0, "wall_2.glb", False),
        (760.9, 487.3, 1.56, 5.24, 0.0, "wall_2.glb", False),
        (761.7, 465.8, 1.56, 5.24, 0.0, "wall_2.glb", False),
        (762.2, 444.8, 1.56, 5.24, 0.0, "wall_2.glb", False),
        (757.4, 424.1, 0.9, 5.24, 0.0, "wall_2.glb", False),
        (739.4, 413.8, 0.21, 5.24, 0.0, "wall_2.glb", False),
        (720.1, 419.0, -0.8, 5.24, 0.0, "wall_2.glb", False),
        (704.6, 436.6, -0.98, 5.24, 0.0, "wall_2.glb", False),
        (692.6, 455.1, -1.08, 5.24, 0.0, "wall_2.glb", False),
        (683.5, 474.4, -1.25, 5.24, 0.0, "wall_2.glb", False),
        (671.5, 490.3, -0.19, 5.24, 0.0, "wall_2.glb", False),
        (366.0, 386.9, -2.17, 8.09, 0.0, "wall_5.glb", False),
        (634.0, 613.1, 0.97, 8.09, 0.0, "wall_5.glb", False),
    ],
    "cliff": [],
    "bush": [
        (430.8, 376.6, 135.3, 30.7, 0.74, False),
        (217.9, 199.4, 97.1, 30.6, 0.93, False),
        (282.9, 367.8, 50.7, 26.8, 0.14, False),
        (189.0, 580.1, 47.1, 24.9, -1.29, False),
        (569.2, 623.4, 135.3, 30.7, 3.88, False),
        (782.1, 800.6, 97.1, 30.6, 4.07, False),
        (717.1, 632.2, 50.7, 26.8, 3.28, False),
        (811.0, 419.9, 47.1, 24.9, 1.86, False),
    ],
    "structure": [
        [
            (150.0, 850.0, 2.34, 70.0, 30.0, "nexus/nexus_7.glb", True),
            (50.0, 790.0, 0.78, 15.0, 0.0, "shop/magic/shop_magic_1.glb", False),
            (250.0, 950.0, 0.78, 12.0, 0.0, "shop/mechanic/shop_mechanic_1.glb", False),
            (185.0, 930.0, -0.0, 12.0, 0.0, "shop/scifi/shop_scifi_1.glb", False),
            (50.0, 700.0, -0.0, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (235.0, 765.0, 0.78, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (300.0, 950.0, 1.57, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (150.0, 800.0, 1.57, 10.0, 0.0, "tower/tower_3.glb", True),
            (200.0, 850.0, -0.0, 10.0, 0.0, "tower/tower_3.glb", True),
            (70.0, 550.0, -0.0, 15.0, 0.0, "tower/tower_1.glb", True),
            (70.0, 300.0, -0.0, 15.0, 0.0, "tower/tower_4.glb", True),
            (320.0, 680.0, 0.78, 15.0, 0.0, "tower/tower_1.glb", True),
            (420.0, 580.0, 0.78, 15.0, 0.0, "tower/tower_4.glb", True),
            (450.0, 930.0, 1.57, 15.0, 0.0, "tower/tower_1.glb", True),
            (700.0, 930.0, 1.57, 15.0, 0.0, "tower/tower_4.glb", True),
        ],
        [
            (850.0, 150.0, -0.8, 70.0, 30.0, "nexus/nexus_7.glb", True),
            (950.0, 210.0, -2.36, 15.0, 0.0, "shop/magic/shop_magic_1.glb", False),
            (750.0, 50.0, -2.36, 12.0, 0.0, "shop/mechanic/shop_mechanic_1.glb", False),
            (815.0, 70.0, 3.14, 12.0, 0.0, "shop/scifi/shop_scifi_1.glb", False),
            (700.0, 50.0, 3.14, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (765.0, 235.0, -2.36, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (950.0, 300.0, -1.57, 10.0, 0.0, "nexus/nexus_3.glb", True),
            (850.0, 200.0, -1.57, 10.0, 0.0, "tower/tower_3.glb", True),
            (800.0, 150.0, 3.14, 10.0, 0.0, "tower/tower_3.glb", True),
            (930.0, 450.0, -3.14, 15.0, 0.0, "tower/tower_1.glb", True),
            (930.0, 700.0, -3.14, 15.0, 0.0, "tower/tower_4.glb", True),
            (680.0, 320.0, -2.36, 15.0, 0.0, "tower/tower_1.glb", True),
            (580.0, 420.0, -2.36, 15.0, 0.0, "tower/tower_4.glb", True),
            (550.0, 70.0, -1.57, 15.0, 0.0, "tower/tower_1.glb", True),
            (300.0, 70.0, -1.57, 15.0, 0.0, "tower/tower_4.glb", True),
            (482.5, 266.4, 2.41, 14.93, 0.0, "tower/tower_3.glb", True),
            (517.5, 733.6, 5.55, 14.93, 0.0, "tower/tower_3.glb", True),
        ],
    ],
}

imported_cache = {}


def clear_blender_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete()


def select_hierarchy(obj):
    obj.select_set(True)
    for child in obj.children:
        select_hierarchy(child)


def move_to_collection(obj, target_col):
    for coll in obj.users_collection:
        coll.objects.unlink(obj)
    if obj.name not in target_col.objects:
        target_col.objects.link(obj)
    for child in obj.children:
        move_to_collection(child, target_col)


def import_map():
    global imported_cache
    imported_cache = {}
    clear_blender_scene()

    for category, items in CONFIG.items():
        if category == "structure":
            for team_idx, team_items in enumerate(items):
                _process_items(category, team_items, f"Team_{team_idx + 1}")
        elif isinstance(items, list) and len(items) > 0 and isinstance(items[0], tuple):
            _process_items(category, items, category.capitalize())


def _process_items(category, items, collection_name):
    global imported_cache

    if collection_name not in bpy.data.collections:
        new_col = bpy.data.collections.new(collection_name)
        bpy.context.scene.collection.children.link(new_col)
    col = bpy.data.collections[collection_name]

    for item in items:
        # --- XỬ LÝ RIÊNG CHO BUSH ---
        if category == "bush":
            # Tuple bush: (x, y, w, h, rotation, destructivity)
            x, y, w, h, rot, destruct = item

            base_name = "bush_placeholder"
            bpy.ops.mesh.primitive_plane_add(size=1)  # Tạo plane 1x1
            target_obj = bpy.context.active_object
            target_obj.name = base_name

            # Scale w, h. Z để là 1 cho an toàn (tránh lỗi scale Z = 0 của Blender)
            target_obj.scale = (w, h, 1.0)

            # Gán vị trí (Bush thường nằm ngay trên mặt đất nên z_offset = 0)
            target_obj.location = (x, MAP_SIZE[1] - y, 0.0)

            # Gán xoay (Dịch ngược góc quay từ Godot config về Blender)
            target_obj.rotation_mode = "XYZ"
            target_obj.rotation_euler[2] = 1.57 - rot

            move_to_collection(target_obj, col)
            continue

        # --- XỬ LÝ CHUNG CHO CÁC OBJECT CÓ FILE .GLB KHÁC ---
        x, y, rot, scale, z_offset, url, destruct = item

        clean_url = url.replace("res://assets/environments/", "").strip("/")

        if category in ["tree", "rock", "wall", "cliff"] and "/" not in clean_url:
            file_path = os.path.join(ASSET_BASE_DIR, category, clean_url)
        else:
            file_path = os.path.join(ASSET_BASE_DIR, clean_url.replace("/", os.sep))

        # Check path
        if not file_path or not os.path.exists(file_path):
            print(f"[Cảnh báo] Không tìm thấy file: {file_path}")
            continue

        target_obj = None
        base_name = clean_url.split("/")[-1].replace(".glb", "")

        if file_path not in imported_cache:
            bpy.ops.object.select_all(action="DESELECT")
            bpy.ops.import_scene.gltf(filepath=file_path)

            imported_objs = bpy.context.selected_objects
            root_obj = None
            for obj in imported_objs:
                if obj.parent is None:
                    root_obj = obj
                    break

            if root_obj:
                root_obj.name = base_name
                imported_cache[file_path] = root_obj
                move_to_collection(root_obj, col)
                target_obj = root_obj
        else:
            # Duplicate Linked từ cache
            base_obj = imported_cache[file_path]
            bpy.ops.object.select_all(action="DESELECT")
            select_hierarchy(base_obj)
            bpy.context.view_layer.objects.active = base_obj
            bpy.ops.object.duplicate(linked=True)

            duplicated_objs = bpy.context.selected_objects
            for obj in duplicated_objs:
                if obj.parent is None:
                    target_obj = obj
                    break

            if target_obj:
                target_obj.name = base_name
                move_to_collection(target_obj, col)

        # Transform các object GLB
        if target_obj:
            target_obj.location = (x, MAP_SIZE[1] - y, z_offset)

            target_obj.rotation_mode = "XYZ"
            root_model_obj = imported_cache[file_path]

            if "initial_rot_z" not in root_model_obj:
                root_model_obj["initial_rot_z"] = root_model_obj.rotation_euler[2]

            target_obj.rotation_euler[2] = root_model_obj["initial_rot_z"] - rot + 1.57

            if isinstance(scale, (list, tuple)):
                target_obj.scale = (scale[0], scale[1], scale[2])
            else:
                target_obj.scale = (scale, scale, scale)


import_map()
print("Import thành công!")

package ui

/*

    layout_frame containers are the default. These containers shrink to the smallest size they need by default, and draws all children on top of each other.

    To find the minimum size, it goes through all children and asks for the minimum size for each, and then uses the highest minimum size found to ensure all children fit inside this container.

    When this element has only one child, this container will wrap tightly into its only child. Padding will be included in calculations

    When this element has multiple children, they will be laid out according to each element's anchor and padding rules. 
    
    TODO: try different approaches, should padding be specified per child? or only one value for the full frame?

*/


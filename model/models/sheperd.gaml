/**
* Name: sheperd
* Based on the internal skeleton template. 
* Author: truonghm
* Tags: 
*/

model sheperd

global {
	int width <- 50;
	int height <- 50;
	float grove_pct <- 0.3;
	int number_of_goats <- 80;
	int number_of_goats_per_herd <- 10;
	
	list<pasture_cell> empty_cells;
	list<rgb> goat_colors <- [rgb(255,0,0), rgb(255,105,180), rgb(128,0,128), rgb(0,255,255), rgb(0,0,255), rgb(0,128,0), rgb(255,165,0), rgb(165,42,42)];
	init {
		empty_cells <- list(pasture_cell);
		create grove number: width * height * grove_pct;
		create goat number: number_of_goats;
		loop c over: goat_colors {
		    
		    ask (number_of_goats_per_herd among goat) {
		    	color <- c;
		    	is_respectful <- flip(0.5);
		    }
		}
	}
}

grid pasture_cell height: 50 width: 50 neighbors: 4 {
	rgb color <- #darkseagreen;
	list<pasture_cell> neighbors2  <- (self neighbors_at 2);
}

species grove {
	rgb color <- #darkgreen;
  
	aspect default {
		draw circle(1) color: color;
	}
}

species goat {
    rgb color <- #beige;
    bool is_respectful <- true;
	pasture_cell my_cell <- one_of (pasture_cell) ;
	
    init {
	location <- my_cell.location;
    }
		
    reflex basic_move {
	my_cell <- one_of (my_cell.neighbors2) ;
	location <- my_cell.location ;
    }

    aspect default {
        draw circle(0.8) color: color;
    }
}

experiment sheperd type: gui {
	output {
		display grid {
			grid pasture_cell;
			species grove;
			species goat;
			
		}
	}
}

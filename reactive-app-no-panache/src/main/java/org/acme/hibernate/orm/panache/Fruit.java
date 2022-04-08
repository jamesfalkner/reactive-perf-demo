package org.acme.hibernate.orm.panache;

import javax.persistence.Cacheable;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.Id;
import javax.persistence.NamedQuery;
import javax.persistence.SequenceGenerator;
import javax.persistence.Table;

@Entity
@Table(name = "fruits")
@Cacheable
@NamedQuery(name = "Fruits.findAll", query = "SELECT f FROM Fruit f ORDER BY f.name")

public class Fruit  {

    private Long id;
    @Id
    @SequenceGenerator(name = "fruitSeq", sequenceName = "fruit_id_seq", allocationSize = 1, initialValue = 1)
    @GeneratedValue(generator = "fruitSeq")
    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    @Column(length = 40, unique = true)
    public String name;

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public Fruit() {
    }

    public Fruit(String name) {
        this.name = name;
    }

}
